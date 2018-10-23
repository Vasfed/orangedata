# Orangedata Client

[![Gem Version](https://badge.fury.io/rb/orangedata.svg)](https://badge.fury.io/rb/orangedata)

A ruby client for orangedata.ru service.
Target service is pretty local to RU, so parts of readme will be in russian.

Note: This is a Work-in-progress. API might change in the future.

Умеет:
- собственно транспорт с подписью запросов
- сгенерировать ключ сразу в нужном виде
- планируется DSL для чеков

## Установка

Все стандартно. Пишем в Gemfile:

```ruby
gem 'orangedata'
```

И давим:

    $ bundle

Либо руками:

    $ gem install orangedata

## Использование

Для тестового окружения ключики в комплекте - [credentials_test.yml](lib/orange_data/credentials_test.yml), собрано из родного `File_for_test.zip`, доступны как `OrangeData::Credentials.default_test`

```ruby
  transport = OrangeData::Transport.new("https://apip.orangedata.ru:2443/api/v2/", OrangeData::Credentials.default_test)

  receipt = {
    id: SecureRandom.uuid,
    inn: '1234567890', key:'1234567890',
    content: { # тут собрать данные можно по официальному мануалу
      type: 1,
      positions:[{ quantity: 1, price: 0.01, tax: 4, text: "Товар на копейку"}],
      checkClose:{
        payments: [{ type:2, amount:'0.01' }],
        taxationSystem: 1
      }
    }
  }
  transport.post_document(receipt)
  # wait some time, then
  transport.get_document("1234567890", receipt[:id])
  # =>
  # {
  #   "id"=>"a88b6b30-20ab-47ea-95ca-f12f22ef03d3",
  #   "deviceSN"=>"1400000000001033",
  #   "deviceRN"=>"0000000400054952",
  #   "fsNumber"=>"9999078900001341",
  #   "ofdName"=>"ООО \"Ярус\" (\"ОФД-Я\")",
  #   "ofdWebsite"=>"www.ofd-ya.ru",
  #   "ofdinn"=>"7728699517",
  #   "fnsWebsite"=>"www.nalog.ru",
  #   "companyINN"=>"1234567890",
  #   "companyName"=>"Тест",
  #   "documentNumber"=>5548,
  #   "shiftNumber"=>6072,
  #   "documentIndex"=>3045,
  #   "processedAt"=>"2018-10-22T19:36:00",
  #   "content"=>
  #     {
  #       "type"=>1,
  #       "positions"=>[{"quantity"=>1.0, "price"=>0.01, "tax"=>4, "text"=>"Товар на копейку"}],
  #       "checkClose"=>{
  #         "payments"=>[{"type"=>2, "amount"=>0.01}],
  #         "taxationSystem"=>1
  #       }
  #     },
  #   "change"=>0.0,
  #   "fp"=>"787980846"
  # }
```

### Получаем сертификаты

Предполагается, что всякие договоры и прочая фискализация уже успешно пройдена и у вас есть доступ
к ЛК orangedata.

Генерируем себе приватный ключ:

```ruby
  c = OrangeData::Credentials.new title:'My production'
  c.generate_signature_key!(2048) # параметр - длина ключа
  #=> возвращает публичный ключ в том виде, который хочет ЛК OrangeData:
  # "<RSAKeyValue><Modulus>(многабукв)==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>"

  File.open("my_production.yml", "wt"){|f| f.write c.to_yaml }
  # (на выходе - yml с приватным ключом и паролем к нему, который надо сохранить и беречь)

  # повторно взять публичный ключ можно так:
  credentials = OrangeData::Credentials.from_hash(YAML.load_file('my_production.yml'))
  credentials.signature_public_xml
```

После чего публичный ключ (xml c `RSAKeyValue`) кормим в ЛК. Значение поля `Название ключа` с этого шага отправляется в `signature_key_name`.
Далее там выпускаем себе сертификаты и из полученного архива вставляем содержимое `<ИНН>.crt` и `<ИНН>.key`(сертификат и ключ к нему) в yml-файлик аналогично примеру.

Если все прошло гладко - теперь у вас есть файлик `my_production.yml` со всеми реквизитами доступа к продакшн-кассе. Обращаться с ним стоит как и с любой другой очень чувствительной информацией, например не стоит коммитить его (ну или как минимум, убрать из него поля `signature_key_pass` и `certificate_key_pass` и хранить отдельно)

## Разработка

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Vasfed/orangedata.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT). Copyright (c) 2018 Vasily Fedoseyev
