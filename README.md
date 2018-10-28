# Orangedata Client

[![Gem Version](https://badge.fury.io/rb/orangedata.svg)](https://badge.fury.io/rb/orangedata)
[![Build Status](https://travis-ci.org/Vasfed/orangedata.svg?branch=master)](https://travis-ci.org/Vasfed/orangedata)

A ruby client for orangedata.ru service.
Target service is pretty local to RU, so parts of readme will be in russian.

Note: This is a Work-in-progress. API might change in the future.

Умеет:
- собственно транспорт с подписью запросов
- сгенерировать ключ сразу в нужном виде
- маппинг для данных генерируется на базе приведенного в человеческий вид официального json-schema-описания

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

Для тестового окружения ключики в комплекте - [credentials_test.yml](lib/orange_data/credentials_test.yml), собрано из родного `File_for_test.zip`, доступны как `OrangeData::Credentials.default_test`.
Получение ключей для продакшна описано ниже.

### Пробитие чека

```ruby
  transport = OrangeData::Transport.new("https://apip.orangedata.ru:2443/api/v2/", OrangeData::Credentials.default_test)
  receipt = OrangeData::Receipt.income(inn:"1234567890"){|r|
    r.customer = "Иван Иваныч"
    r.add_position("Спички", price: 12.34){|pos| pos.tax = :vat_not_charged }
    r.add_payment(50, :cash)
  }
  transport.post_document(receipt)
  # wait some time
  res = transport.get_document(receipt.inn, receipt.id)

  # => (внутри такое, а вернет объект)
  # {
  # "id"=>"50152258-a9aa-4d19-9216-5a3eecec7241",
  # "deviceSN"=>"1400000000001033",
  # "deviceRN"=>"0000000400054952",
  # "fsNumber"=>"9999078900001341",
  # "ofdName"=>"ООО \"Ярус\" (\"ОФД-Я\")",
  # "ofdWebsite"=>"www.ofd-ya.ru",
  # "ofdinn"=>"7728699517",
  # "fnsWebsite"=>"www.nalog.ru",
  # "companyINN"=>"1234567890",
  # "companyName"=>"Тест",
  # "documentNumber"=>3243,
  # "shiftNumber"=>234,
  # "documentIndex"=>7062, "processedAt"=>"2018-10-26T20:21:00",
  # "content"=>{
  #   "type"=>1,
  #   "positions"=>[{"price"=>12.34, "tax"=>6, "text"=>"Спички"}],
  #   "checkClose"=>{"payments"=>[{"type"=>1, "amount"=>50.0}], "taxationSystem"=>0},
  #   "customer"=>"Иван Иваныч"
  # },
  # "change"=>37.66,
  # "fp"=>"301645583"
  # }

  res.device_sn
  # => "1400000000001033"

  # и даже так:
  res.qr_code_content
  # => "t=20181026T2021&s=50.0&fn=9999078900001341&i=3243&fp=301645583&n=1"
```

### Чек коррекции
Пока не понятно, почему в API не все значения поля tax соответствуют цифрам в `taxNSum`, поэтому коррекцию, видимо, лучше бить через саппорт или подобным образом.

Но поддержка в маппинге есть:

```ruby
transport = OrangeData::Transport.new("https://apip.orangedata.ru:2443/api/v2/", OrangeData::Credentials.default_test)
correction = OrangeData::Correction.income(inn:"123456789012", id:"12345678990"){|c|
  c.correction_type = :prescribed
  c.assign_attributes(
    description: "НЕ ХОЧЕТСЯ НО НАДО",
    cause_document_date: "2017-08-10T00:00:00", cause_document_number: "ФЗ-54",
    total_sum: 17.25,
    sum_cash: 1.23, sum_card: 2.34,
    sum_prepaid: 5.67, sum_credit: 4.56, sum_counterclaim: 3.45,

    vat_18: 1.34, vat_10: 2.34, vat_0: 3.34,
    vat_not_charged: 4.34, vat_18_118: 5.34, vat_10_110: 6.34,
    taxation_system: :simplified,

    automat_number: "123456789",
    settlement_address: "г.Москва, Красная площадь, д.1",
    settlement_place: "Палата No6",
  )
}
transport.post_correction(correction)
# wait some time
res = transport.get_correction(correction.inn, correction.id)
```


### Получаем сертификаты

Предполагается, что всякие договоры и прочая фискализация уже успешно пройдена и у вас есть доступ
к ЛК orangedata.

В [ЛК в разделе интеграций](https://lk.orangedata.ru/lk/integrations/direct) запрашиваем сертификат (шаг 3, первый шаг не нужен, а данные для второго получатся ниже), распаковываем полученный zip-архив и натравливаем туда генератор:

```ruby
  c = OrangeData::Credentials.read_certs_from_pack('~/Downloads/1234567890', title:'My production', cert_key_pass:'1234') # cert_key_pass берем из readme_v2.txt, но есть подозрение что он у всех 1234
  File.open("my_production.yml", "wt"){|f| f.write c.to_yaml }
  c.signature_public_xml
  # "<RSAKeyValue>...</Exponent></RSAKeyValue>"

  # опционально на маке копируем публичный ключ в буфер обмена:
  system("echo '#{c.signature_public_xml}' | pbcopy")
```

Если все прошло гладко - теперь у вас есть файлик `my_production.yml` со всеми реквизитами доступа к продакшн-кассе. Обращаться с ним стоит как и с любой другой очень чувствительной информацией, например не стоит коммитить его (ну или как минимум, убрать из него поля `signature_key_pass` и `certificate_key_pass` и хранить отдельно)

Дальше публичный ключ с предыдущего шага отправляется в ЛК, там его сохряняем, "подключаем интеграцию", и пользуемся:

```ruby
  transport = OrangeData::Transport.new(OrangeData::Transport::DEFAULT_PRODUCTION_API_URL, OrangeData::Credentials.from_hash(YAML.load_file('my_production.yml')))
  transport.post_document # и далее по тексту, осторожно - не пробейте лишние чеки во время проверок
```

## Разработка

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Vasfed/orangedata.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT). Copyright (c) 2018 Vasily Fedoseyev
