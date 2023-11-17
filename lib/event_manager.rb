require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phone_numbers(number)
  number.gsub!(/[^0-9A-Za-z]/, '')
  return 'Bad Number' if number.length < 10 || number.length > 11
  return number if number.length == 10

  number[1..10] if number.length == 11
end

def get_average_reg_hour(date_times)
  "Peak registration hour is #{date_times.map { |dt| dt.hour.to_i}.sum / date_times.length}:00"
end

def get_days_of_registration(date_times)
  day_counts = Hash.new(0)
  date_times.each do |dt|
    day_of_week = dt.wday
    day_name = Date::DAYNAMES[day_of_week]
    day_counts[day_name] += 1
  end
  day_counts
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

array_of_times = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_numbers(row[:homephone])
  array_of_times.push(DateTime.strptime(row[:regdate], '%m/%d/%y %H:%M'))
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end

pp get_average_reg_hour(array_of_times)
puts 'These are the number of registrations per each day of the week (if a day is not included then no one registered on that day):'
pp get_days_of_registration(array_of_times)
