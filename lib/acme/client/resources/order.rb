# frozen_string_literal: true

class Acme::Client::Resources::Order
  attr_reader :url, :status, :contact, :finalize_url, :identifiers, :authorization_urls, :expires, :certificate_url

  def initialize(client, **arguments)
    @client = client
    @alternate_links = []
    assign_attributes(**arguments)
  end

  def reload
    assign_attributes(**@client.order(url: url).to_h)
    true
  end

  def authorizations
    @authorization_urls.map do |authorization_url|
      @client.authorization(url: authorization_url)
    end
  end

  def finalize(csr:)
    assign_attributes(**@client.finalize(url: finalize_url, csr: csr).to_h)
    true
  end

  def certificate(preferred_chain: nil)
    if certificate_url
      default_certificate, @alternate_links = @client.certificate(url: certificate_url)
      if preferred_chain
        certificate = pickup_preferred_chain([default_certificate, alternative_certificates].flatten, preferred_chain)
        raise Acme::Client::Error::NotFound, "Intermediate CA certificate with #{preferred_chain} was not found." unless certificate
        certificate
      else
        default_certificate
      end
    else
      raise Acme::Client::Error::CertificateNotReady, 'No certificate_url to collect the order'
    end
  end

  def to_h
    {
      url: url,
      status: status,
      expires: expires,
      finalize_url: finalize_url,
      authorization_urls: authorization_urls,
      identifiers: identifiers,
      certificate_url: certificate_url
    }
  end

  private

  def assign_attributes(url:, status:, expires:, finalize_url:, authorization_urls:, identifiers:, certificate_url: nil)
    @url = url
    @status = status
    @expires = expires
    @finalize_url = finalize_url
    @authorization_urls = authorization_urls
    @identifiers = identifiers
    @certificate_url = certificate_url
  end

  def pickup_preferred_chain(certificates, preferred_chain)
    certificates.find do |cert|
      OpenSSL::X509::Certificate.new(split_certificates(cert).last).issuer.to_a.flatten.include?(preferred_chain)
    end
  end

  def alternative_certificates
    @alternate_links.map do |certificate_url|
      certificate, = @client.certificate(url: certificate_url)
      certificate
    end
  end

  def split_certificates(certificates)
    delimiter = "\n-----END CERTIFICATE-----\n"
    certificates.split(delimiter).map{ |c| c + delimiter }
  end
end
