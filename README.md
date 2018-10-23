# Orangedata Client

[![Gem Version](https://badge.fury.io/rb/orangedata.svg)](https://badge.fury.io/rb/orangedata)
[![Build Status](https://travis-ci.org/Vasfed/orangedata.svg?branch=master)](https://travis-ci.org/Vasfed/orangedata)

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

В [ЛК в разделе интеграций](https://lk.orangedata.ru/lk/integrations/direct) запрашиваем сертификат (шаг 3, первый шаг не нужен, а данные для второго получатся ниже), распаковываем полученный zip-архив и натравливаем туда генератор:

```ruby
  c = OrangeData::Credentials.read_certs_from_pack('~/Downloads/1234567890', title:'My production', cert_key_pass:'1234') # cert_key_pass берем из readme_v2.txt, но есть подозрение что он у всех 1234
  # Generated public signature key: <RSAKeyValue>...</Exponent></RSAKeyValue>
  File.open("my_production.yml", "wt"){|f| f.write c.to_yaml }

  # опционально на маке копируем публичный ключ в буфер обмена:
  system("echo '#{c.signature_public_xml}' | pbcopy")
```

Если все прошло гладко - теперь у вас есть файлик `my_production.yml` со всеми реквизитами доступа к продакшн-кассе. Обращаться с ним стоит как и с любой другой очень чувствительной информацией, например не стоит коммитить его (ну или как минимум, убрать из него поля `signature_key_pass` и `certificate_key_pass` и хранить отдельно)

Дальше публичный ключ с предыдущего шага отправляется в ЛК, там его сохряняем, "подключаем интеграцию", и пользуемся:

```ruby
  transport = OrangeData::Transport.new(OrangeData::Transport::DEFAULT_PRODUCTION_API_URL, OrangeData::Credentials.from_hash(YAML.load('my_production.yml')))
  transport.post_document # и далее по тексту, осторожно - не пробейте лишние чеки во время проверок
```

## Разработка

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Vasfed/orangedata.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT). Copyright (c) 2018 Vasily Fedoseyev
