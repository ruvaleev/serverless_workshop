require 'httparty'
require 'json'
require 'telegram/bot'

def parsed_result(query)
  url = "https://api.themoviedb.org/3/search/movie?query=#{query}&include_adult=false&language=en-US&page=1"
  headers = {
    'Authorization' => "Bearer #{ENV['API_TOKEN']}",
    'Accept' => 'application/json'
  }
  
  response = HTTParty.get(url, headers: headers)
  parsed = JSON.parse(response.body)

  movie_entity(parsed['results'][0])
end

def movie_entity(movie)
  "
  Полное название: #{movie['original_title']}
  Описание: #{movie['overview']}
  Рейтинг: #{movie['vote_average']}
  Дата выхода: #{movie['release_date']}
  Постер: https://image.tmdb.org/t/p/w200#{movie['poster_path']}
  "
end

def telegram_bot
  @telegram_bot ||= Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
end

def lambda_handler(event:, context:)
  puts event
  body = JSON.parse(event['body'])
  message = body['message']
  chat_id = body['message']['chat']['id']

  text = parsed_result(message['text'])
  puts text
  telegram_bot.api.send_message(chat_id:, text:)
  rescue => e
    puts e
  ensure
    {
      statusCode: 200,
      body: {
        message: 'ok'
      }
    }
end

