import X509

public extension Certificate {

    static func testValue() throws -> Certificate {
        try Certificate(
            pemDocument: .init(pemString: """
            -----BEGIN CERTIFICATE-----
            MIIFMzCCBBugAwIBAgIEVh0e3jANBgkqhkiG9w0BAQsFADCBhjELMAkGA1UEBhMC
            VVMxEzARBgNVBAcMCldpbG1pbmd0b24xFTATBgNVBAoMDFByb3h5bWFuIExMQzE4
            MDYGA1UEAwwvUHJveHltYW4gQ0EgKDQgSnVuIDIwMjUsIHBib29rLmxvY2FsLCBB
            QTk0NzU5RikxETAPBgNVBAgMCERlbGF3YXJlMB4XDTI1MDYwMzE3MTM0M1oXDTI3
            MDkwNzE3MTM0M1owgYYxCzAJBgNVBAYTAlVTMRMwEQYDVQQHDApXaWxtaW5ndG9u
            MRUwEwYDVQQKDAxQcm94eW1hbiBMTEMxODA2BgNVBAMML1Byb3h5bWFuIENBICg0
            IEp1biAyMDI1LCBwYm9vay5sb2NhbCwgQUE5NDc1OUYpMREwDwYDVQQIDAhEZWxh
            d2FyZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKw955efGXg7d/VT
            GzG0luKjlgznDRP3OgeIiAEsgBtc4ufzRYj07LEKIjwULJINE1GuhUr2gna990xO
            EpajeL06sbHiYwDiTh0u61Pww6g+xADQvPFbkcP8ItTqKRkVksFrELVYt8saO5xG
            5lazQJ2lPIGC+hHZkkzbXWU69vsXuO3JrWBEGZlQqosQRTFy/3dvZiSij45jORrT
            +lXiPR1m9dNdmj9ebKhkrc1XzvjDQB8GUAcycWMOamAvNk+fhHnF7PRrEi3Wp+1p
            wskdcrcoB3gPq4JO2hezlWOWIaCBLDfD0K/vQhuaBzo8ZAXaywWqQ9zE8Nzfhc+M
            s4r+eDcCAwEAAaOCAaUwggGhMA4GA1UdDwEB/wQEAwICBDAPBgNVHRMBAf8EBTAD
            AQH/MB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQUndfB
            AfTYEon08bMtBHC1SaCHGxIwHwYDVR0jBBgwFoAUndfBAfTYEon08bMtBHC1SaCH
            GxIwggEdBglghkgBhvhCAQ0EggEOFoIBClRoaXMgUm9vdCBjZXJ0aWZpY2F0ZSB3
            YXMgbG9jYWxseSBnZW5lcmF0ZWQgYnkgUHJveHltYW4gZm9yIFNTTCBQcm94eWlu
            Zy4gSWYgeW91IGFyZSBicm93c2luZyBhIHdlYnNpdGUgdGhyb3VnaCBQcm94eW1h
            biB3aXRoIFNTTCBQcm94eWluZyBlbmFibGVkLCB5b3Ugd291bGQgc2VlIHRoaXMg
            Y2VydGlmaWNhdGUgYXMgYSBwYXJ0IG9mIGEgY2VydGlmaWNhdGUgY2hhaW4uIFBs
            ZWFzZSBzZWUgaHR0cHM6Ly9wcm94eW1hbi5jb20gZm9yIG1vcmUgaW5mb3JtYXRp
            b24uMA0GCSqGSIb3DQEBCwUAA4IBAQCofOGU7rETcGSy4w3mIap/iyHQoYGmtUKS
            8k8inweW8h/Z4Iyn0qJiI3WAPNHjGQurfmL2Hx0vNwX1UH4glM36QZHXRh38ZlUn
            I4aY2Zlhsr2hg72lf0pJWyt+XICTiygL0K+1XNYAA5MGLD+kOH8WnsZD9J3Mms5w
            Z1bSwbWQdB0nffEWtm/R0RajZcnEYDAc8vEhC3jFalhAgqg85Tvc+I4brntm3sQ+
            6VOcKl92z1+if3hXYKyUa6fLX5SFvpLBK9LEntS2vadpN0klfnIzt+rfqBoluYD7
            EhDpbjzJKGwBn+YlRb+PZoWz6oWwUvlor1zvSoTwIDSOzh7Ia9eP
            -----END CERTIFICATE-----
            """)
        )
    }
}
