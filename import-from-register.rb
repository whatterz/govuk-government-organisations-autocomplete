require 'open-uri'
require 'json'

url = 'https://government-organisation.register.gov.uk/entries.json?limit=5000'

data = open(url).read

json = JSON.parse(data)

items = json.collect do |entry|
  {timestamp: entry['entry-timestamp'], item_hashes: entry['item-hash']}
end

all_entry_data = []

i = 1

items.each do |item|

  item[:item_hashes].each do |item_hash|


    print "#{i}/#{items.size}\r"
    STDOUT.flush
    data = open("https://government-organisation.register.gov.uk/item/#{item_hash}.json").read
    json = JSON.parse(data)

    all_entry_data << {timestamp: item[:timestamp], data: json}

        i += 1

  end


end

grouped_by_key = all_entry_data.group_by {|entry| entry[:data]['government-organisation'] }

final = []

grouped_by_key.each_pair.collect do |key, values|

  current_data = values.sort_by {|value| value[:timestamp] }.last[:data]

  current_name = current_data['name']

  all_names = values.collect {|value| value[:data]['name'] }.uniq

  final << {
    'key' => key,
    'current_name' => current_name,
    'other_names' => all_names - [current_name],
    'start_date' => current_data['start-date'],
    'end_date' => current_data['end-date']
  }
end

json_file = File.open('data.json', 'r')

existing_orgs = JSON.parse(json_file.read)

final.each do |register_org|

  existing_org = existing_orgs.detect {|org| org['key'] == register_org['key'] }

  if existing_org.nil?
    # puts "FOUND ONE:" + register_org['current_name']
    existing_org = register_org
    existing_orgs << existing_org
  end

  existing_org['current_name'] = register_org['current_name']
  existing_org['other_names'] = (existing_org['other_names'] + register_org['other_names']).uniq.sort
  existing_org['start_date'] = register_org['start_date']
  existing_org['end_date'] = register_org['end_date'] unless register_org['end_date'].nil?

end

json_file.close

json_file = File.open('data.json', 'w')

json_file.write JSON.pretty_generate(existing_orgs.sort_by {|org| org['key']})

json_file.close
