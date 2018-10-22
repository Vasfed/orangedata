# frozen_string_literal: true

RSpec.describe 'OrangeData::Transport' do

  let(:test_credentials){
    OrangeData::Credentials.from_hash({
      certificate:
        "-----BEGIN CERTIFICATE-----\nMIIDYjCCAkoCAQAwDQYJKoZIhvcNAQELBQAwcTELMAkGA1UEBhMCUlUxDzANBgNV\nBAgMBk1vc2NvdzEPMA0GA1UEBwwGTW9zY293MRMwEQYDVQQKDApPcmFuZ2VkYXRh\nMQ8wDQYDVQQLDAZOZWJ1bGExGjAYBgNVBAMMEXd3dy5vcmFuZ2VkYXRhLnJ1MB4X\nDTE4MDMxNTE2NDYwMVoXDTI4MDMxMjE2NDYwMVowfTELMAkGA1UEBhMCUlUxDzAN\nBgNVBAgMBk1vc2NvdzEPMA0GA1UEBwwGTW9zY293MR8wHQYDVQQKDBZPcmFuZ2Vk\nYXRhIHRlc3QgY2xpZW50MRMwEQYDVQQLDApFLWNvbW1lcmNlMRYwFAYDVQQDDA1v\ncmFuZ2VkYXRhLnJ1MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo7XZ\n+VUUo9p+Q0zPmlt1eThA8NmVVAgNXkVDZoz3umyEnnm2d4R5Voxf4y6fuesW3Za8\n/ImKWLbQ3/S/pHZKWiz75ElSfpnYJfMRuLAaqqs0eFfxmHbHi8Mgg9zjAMdILpR6\neEaP7qeCNRom3Zb6ziYoWEmDC2ZFFu9995rjkn7CtV3noWZveOCGExjM7WTkql8L\nv1PX3ee3fXaEC7Kefxl4O/4w7agEceKRHlc0l3iwVJaKittQwAQd3ieUwoqsxzPH\ndRwB4IU9aI6IjfqteyD51s7xd+ayM/O4j+aJ/HBhJajDHBcGWKytxv0f6YpqPUAc\n25fRAXVa0Gsei6eY/QIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQCv/Vcxh2lMt8RV\nAl0V9xIst0ZdjH22yTOUCOiH9PZgeagqrjTLT3ycWAdbZZUpzcFSdOmPUsgQ7Eqz\n+TpcY5lmYFInLwJK/Afjqsb5LK2irGKT254p5qzD9rSRlM42wxRzQTA0BWX3mmhi\nzwdrfLAvyCw1gHBbUZNf3eemBCY+8RRGPRAqD2XbyIya1bX0AHLXbx5dBe9EIOG/\nF46WbTlrkR7kc06eiacTiGYwNdcywJ2KOcvmnXPup8Os6KOWe197CIathDHeiG2C\nmQlsQDF/d7W4G/+l6Q66BhfRtuhp99gkT8P8j82X6ChrwbgQ5+vya3SytJ0wmIg2\n67jOKmGK\n-----END CERTIFICATE-----\n",
      certificate_key:
        "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCjtdn5VRSj2n5D\nTM+aW3V5OEDw2ZVUCA1eRUNmjPe6bISeebZ3hHlWjF/jLp+56xbdlrz8iYpYttDf\n9L+kdkpaLPvkSVJ+mdgl8xG4sBqqqzR4V/GYdseLwyCD3OMAx0gulHp4Ro/up4I1\nGibdlvrOJihYSYMLZkUW7333muOSfsK1XeehZm944IYTGMztZOSqXwu/U9fd57d9\ndoQLsp5/GXg7/jDtqARx4pEeVzSXeLBUloqK21DABB3eJ5TCiqzHM8d1HAHghT1o\njoiN+q17IPnWzvF35rIz87iP5on8cGElqMMcFwZYrK3G/R/pimo9QBzbl9EBdVrQ\nax6Lp5j9AgMBAAECggEAL5qkrKT54H+bcZR3Vco8iag68g5DJvFEeeIoLDzXmGUP\n10lLLsvdwLYG9/fJyHU86+h2QfT4vr1CVa1EwN0I19n20TYk/91ahgZ9Y7gJuREZ\nq9jeztfTRKfT36Quej54ldrlFe5m0h3xdeGJ5auOeL2Nw8Z0ja8KbhXsCkEG5cTx\nZvXB0XlFoAJOp8AZvU3ZNBpmpItFlcl2aBXwRCb72DUjLkpnZf2kFDNorc1wFZ2e\nDO/pujT6EtQ1r5qb2kUuj4GpCaHffOB/ukz3dg3bBhompTYdhax0RlZs2vNsUusm\n6oYsUS5nWmJfnrh32Te03Fdzc2U8/XUflJzKL/0QvQKBgQDOpNQvCCxwvthZXART\nq0fl9NY0fxlSqUpxd1BB4DYCg6Sg5kVvfwf7rdb5bbP4aNCC/9m4MgXTD0DGfEhM\nFnYPVNKTzwLMBftBQdzDN6766j5lI49evwnh855EFAR5GyaIWh2n7tT3NUOstogp\nkpwhzsPGH1WkEO1QLcBDyzPI3wKBgQDKz94V8au1EVKuRBR+c5gNJpF+zmUu2t2C\nZlPtYIuWaxMbqitmeCmNBQQZK+oLQdSUMkgMvYVpKriPk6AgnY7+1F+OOeg+ezPU\nG+J4Vi8Yx/kZPhXoBuW745twux+q8WOBwEj2WeMy5p1F/V3qlu70HA3kbsrXdB+R\n0bFVAxCtowKBgFTtq4M08cbYuORpDCIzGBarvMnQnuC5US43IlYgxzHbVvMGEO2V\nIPvQY7UZ4EitE11zt9CbRoeLEk1BURlsddMxQmabQwQFRVF5tzjIjvLzCPfaWJdR\nHsetr5M9QuVfQkPx/ZRCdWawjoLSdj3X0rGWYCHySOloR5CXbRiv0DWzAoGAF3XW\nLdmn0Ckx1EDB0iLS+up0OCPt5m6g4v2tRa8+VmcKbc/Qd2j8/XgQEk1XJHg3+/CZ\nDwg5T4IGmW0tP7iaGvY8G3qtV9TumOGk3+CwUACJ2xaoeA+cMZDRoUe0ERUdOpwg\nlIavVmsA1GDLpWBSQeCg5sS+KBAhur9z8O6K1lsCgYEAj7TLLE0jLNXRRfkfWzy5\nRsJezMCQS9fjtJrLGB3BbYxqtebP2owp1qjmKMQioW5QjRxRCOyT2KrHjb31hRsp\nHk3Wi0OKOEuKNwmAZczbjcPH4caPZPeL6LMDtFFMsFX2BW7TnC8FcoVr2KPO/FG/\nxs4KtXC9j5rrvBowJ0LbJ2U=\n-----END PRIVATE KEY-----\n",
      certificate_key_pass: '1234',
      signature_key_name: '0', # usually INN
      signature_key:
        "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAt8nC/Eth8UabQbXu8pdro3v7NqUanV8Y+g92YgT7z1xqkBLR\nHXZ1guml3PxrqjNX9AvOmu8R+qaKOyHfJW0PcRDLzCoIUcHNAwpDO/E5j6WAaLIv\n7gAjTtyr9kJB9rfJaparViJNZu3RSUYGTvVznOmXMf7LTOTMR6HP/5H1TP5n1g4+\nBbLmC9EhjUf2eNFqwZBqPtzybBb6jaHBRaJ0XdE3lh2OeE9/OF0BtLwiYPDKsVTx\nIekbNf7l/DREy+YbUOxQLceeHXrvbYLiGWecP0a7CqHGj9ZNY1oJThK3AwrSd4yH\na9Wnx/GaZUNtWud1BaP9g3sVX+sRV9xtnI96dwIDAQABAoIBAD1HzPgKupGUlVgH\nrbC9xGoygMTrsEAg4VcfqL1uI/g0PGPlokxMn0oTVfalQ9DwZbc96JnIdRo6RYUJ\n+jmkb62niAx/R17bW9xTo69s82BuMq62Gz0kVqGI+t2VoiD9ju83ZdHGhkB3s3zX\nGGtjdDUxvfQxnN/6uhJ4Zb41kLEm4hI5sXD8fH5ldYuA6H5TEN/N57IsQBWqYK0T\nlALQoDL4Vp9ZEnqKIynfnuHimcWv0jWLpbASVjRZJqNQmR+GE6pTzPiMGHg1Dpzl\nBjcRrq0Wd6kHVrNjdmUIZ675Yfs6c7qw9ocAM+oEFz+5scTEdcR7QA/F0PsODoiS\nulVo6CECgYEA3WSb72a1erb6jcLkyZA2Y21VNIipGz+ta1RP+iacs3xnktFsxgTY\ngqWyt6SWZ2rStp0u4vb/IAHyKhgJPNTUSi2u0G44MOsRxMC/FWTF8zdyrDF4BjPB\nM4j84nAmE/FQYv5F8ldDkakc96zEPiTk5Fka3MPeN8mMk6/OA59JdF0CgYEA1IRV\nid5SsDrOwJQAEKkdT436XEb0sVWe9AcU8JyaCEEMj0NPzownNbIrebPofMYdDHik\nopQpr2XqxZYDbb7AneoHkhEV26TfpPVbN4wBJFXih3lAP2n5hqhgqHGp5Wq2Lu7j\nUS376Ruw3bhwW+MiWpXv1xhMTZ8AtDfnZFFNvOMCgYAWjkqI0IkK0JukV8fhdUzl\nQl1c9dNs0EcF2Vgwn0B11OXkgmu3nQTGAsW7igw8yxhevJLrUsjZZPlcKoi+Ztye\nFhtqZuBYs4pi5lRRhKvaRLrtKjkVQK6dZoaFN3HZtEtBWrCbqSJcM8OcxEBWKIId\ndaqT9WyteF5XKaEuo0rjjQKBgQCajBJYzOF9X4bz7a2OcC3sqOelK8TPIeESvgOw\nZ3JtBkFH/j+PicUJ+6Q6QWeVNc3yP9oakX0vHQL65flgWhRhwsv2oY4vyVsK75OC\ndcJu1jaDJt5eP4dDMjf4x5AyUsRipT+Szcog4A5jb7nmWOumzNs6pWT4HeW5Kd6Q\nyb+q2QKBgGj+XuRdY+rPNj5u3QqR95kWVp32SCqqDUCKtgTvLwPf1q3RSNgtu7jY\ncQqdmQzLpUXQWXKHh3MCY58g84OCOIAWdp0ipFXZTdURKE4ywQXZR4vFyol88b6S\nLXNsIzQtgCh2iao/3Z4d220wEA9YlAMT5piyWGJIX2dotSK01cWR\n-----END RSA PRIVATE KEY-----\n",
      signature_key_pass: '1234'
    })
  }

  subject{ OrangeData::Transport.new("https://apip.orangedata.ru:2443/api/v2/", test_credentials) }

  it "signs post requests" do
    expected_body = '{"some":"data"}'
    req = stub_request(:post, "https://apip.orangedata.ru:2443/api/v2/test").
       with(
         body: expected_body,
         headers: {
           'User-Agent'=>'OrangeDataRuby/0.0.1',
           'Accept'=>'application/json',
           'Content-Type'=>'application/json',
           'X-Signature'=>Base64.strict_encode64(
             test_credentials.signature_key.sign(OpenSSL::Digest::SHA256.new, expected_body)
           )
         }).
       to_return(status: 200, body: '{"this":"is a response"}', headers: {'Content-type' => 'application/json'})

    res = subject.raw_post('test', some: 'data')
    expect(res).to be_success
    expect(res.body).to eq('this' => 'is a response')
    expect(req).to have_been_made
  end
end
