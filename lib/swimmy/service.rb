module Swimmy
  module Service
    dir = File.dirname(__FILE__) + "/service"

    autoload :Pokemoninfo, "#{dir}/pokemoninfo.rb"
    autoload :Geocoding,   "#{dir}/geocoding.rb"
    autoload :Weather,     "#{dir}/weather.rb"
    autoload :Anniversary, "#{dir}/anniversary.rb"
    autoload :Coronainfo,  "#{dir}/coronainfo.rb"
    autoload :RestaurantInfo, "#{dir}/restaurant_info.rb"
    autoload :CalendarService,    "#{dir}/calendar_service.rb"
    autoload :AttendanceLogger,  "#{dir}/attendance_logger.rb"
    autoload :Doorplate,   "#{dir}/doorplate.rb"
    autoload :Pollen,      "#{dir}/pollen_service.rb"
    autoload :CityCode,    "#{dir}/city_code.rb"
    autoload :Openhab, "#{dir}/openhab.rb"
    autoload :Newsapi, "#{dir}/newsapi.rb"
    autoload :Coop, "#{dir}/coop.rb"
    autoload :Nomnichi, "#{dir}/nomnichi.rb"
    autoload :RecipeInfomation, "#{dir}/recipe_information.rb"
    autoload :GoogleCalendar, "#{dir}/schedule_service.rb"
  end
end
