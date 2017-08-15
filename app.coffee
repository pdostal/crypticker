moment = require 'moment'
yamljs = require 'yamljs'
request = require 'request'
redisjs = require 'redis'
mqttjs = require 'mqtt'
cronjob = require('cron').CronJob


logger = (msg) ->
  console.log moment().format('DD. MM. YYYY, hh:mm:ss') + ' ' + msg

settings = yamljs.load 'settings.yml'
redis = redisjs.createClient({host: 'redis'})
mqtt = mqttjs.connect { host: settings.mqtt_host, port: settings.mqtt_port, protocolId: 'MQIsdp', protocolVersion: 3 }

redis.on "error", (err) ->
  logger "Error " + err


new cronjob '0 * * * * *', ->
  settings.wallets.BTC.forEach (item, order) ->
    request 'https://min-api.cryptocompare.com/data/price?fsym=BTC&tsyms=USD,EUR&e=Coinbase&extraParams=PDostal', (error, response, body) ->
      redis.set "BTC", JSON.parse(body).USD
      logger "BTC: #{JSON.parse(body).USD}"
    request "https://blockchain.info/rawaddr/#{item.address}", (error, response, body) ->
      redis.set "BTC#{item.address}", '0.0'+JSON.parse(body).final_balance
      logger "BTC#{item.address} 0.0#{JSON.parse(body).final_balance}"
  settings.wallets.LTC.forEach (item, order) ->
    request 'https://min-api.cryptocompare.com/data/price?fsym=LTC&tsyms=USD,EUR&e=Coinbase&extraParams=PDostal', (error, response, body) ->
      redis.set "LTC", JSON.parse(body).USD
      logger "LTC: #{JSON.parse(body).USD}"
    request "http://explorer.litecoin.net/chain/Litecoin/q/addressbalance/#{item.address}", (error, response, body) ->
      redis.set "LTC#{item.address}", body
      logger "LTC#{item.address} #{body}"
, null, true


new cronjob '30 * * * * *', ->
  redis.get "BTC", (err, btc) ->
    mqtt.publish "#{settings.mqtt_topic}BTC_USD", btc
    settings.wallets.BTC.forEach (item, order) ->
      redis.get "BTC#{item.address}", (err, res) ->
        mqtt.publish "#{settings.mqtt_topic}BTC_#{item.address}", res
        mqtt.publish "#{settings.mqtt_topic}BTC_#{item.address}_USD", "#{btc*res}"
        logger "#{item.name}: #{res}BTC = #{btc*res}USD (1BTC=#{btc}USD)"
  redis.get "LTC", (err, ltc) ->
    mqtt.publish "#{settings.mqtt_topic}LTC_USD", ltc
    settings.wallets.LTC.forEach (item, order) ->
      redis.get "LTC#{item.address}", (err, res) ->
        mqtt.publish "#{settings.mqtt_topic}LTC_#{item.address}", res
        mqtt.publish "#{settings.mqtt_topic}LTC_#{item.address}_USD", "#{ltc*res}"
        logger "#{item.name}: #{res}LTC = #{ltc*res}USD (1LTC=#{ltc}USD)"
, null, true

process.on 'SIGTERM', ->
  console.log 'Exitting...'
