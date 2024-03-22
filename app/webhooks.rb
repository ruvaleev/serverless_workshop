require 'aws-sdk-dynamodb'
require 'httparty'
require 'json'
require 'telegram/bot'

TTL_DAYS = 7

def request_in_api(query)
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

def dynamodb
  @dynamodb ||= Aws::DynamoDB::Client.new
end

def telegram_bot
  @telegram_bot ||= Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
end

def find_in_db(query)
  params = {
    table_name: ENV['DYNAMODB_TABLE'],
    index_name: ENV['DYNAMODB_INDEX_NAME'],
    expression_attribute_values: {
      ':query' => query
    },
    key_condition_expression: 'message = :query',
    limit: 1
  }
  
  result = dynamodb.query(params)
  result[:items].first
end

def save_to_db(message, query, text)
  request_info = {
    timestamp: message['date'],
    message: query,
    name: message['from']['first_name'],
    id: message['message_id'],
    result: text,
    ttl: Time.now.to_i + TTL_DAYS * 24 * 60 * 60
  }

  resp = dynamodb.put_item(
    table_name: ENV['DYNAMODB_TABLE'],
    item: request_info,
    return_consumed_capacity: 'INDEXES'
  )

  puts JSON.pretty_generate(resp)
end

def with_no_errors(&block)
  yield
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

def lambda_handler(event:, context:)
  with_no_errors do
    puts event
    body = JSON.parse(event['body'])
    message = body['message']
    query = message['text'].downcase
    chat_id = body['message']['chat']['id']

    record = find_in_db(query)
    if record
      telegram_bot.api.send_message(chat_id:, text: record['result'])
    else
      text = request_in_api(query)
      telegram_bot.api.send_message(chat_id:, text:)
      save_to_db(message, query, text)
    end
  end
end

