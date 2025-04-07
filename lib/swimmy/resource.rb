module Swimmy
  module Resource
    dir = File.dirname(__FILE__) + "/resource"

    autoload :Memo,        "#{dir}/memo.rb"
    autoload :Attendance,  "#{dir}/attendance.rb"
    autoload :Place,       "#{dir}/place.rb"
    autoload :Weather,     "#{dir}/weather.rb"
    autoload :Member,      "#{dir}/member.rb"
    autoload :Calendar,    "#{dir}/calendar.rb"
    autoload :Anniversary, "#{dir}/anniversary.rb"
    autoload :Recurrence,  "#{dir}/schedule.rb"
    autoload :Occurence,   "#{dir}/schedule.rb"
    autoload :CoronaInfo,  "#{dir}/coronaresource.rb"
    autoload :Restaurant,  "#{dir}/restaurant.rb"
    autoload :GoogleOAuth, "#{dir}/google_oauth.rb"
    autoload :Event,       "#{dir}/event.rb"
    autoload :Pollen,      "#{dir}/pollen_resource.rb"
    autoload :OpenhabMetadata, "#{dir}/openhab_metadata.rb"
    autoload :CoopShop,         "#{dir}/coop_info.rb"
    autoload :NomnichiArticle,  "#{dir}/nomnichi_article.rb"
    autoload :CookResource, "#{dir}/cook_resource.rb"
    autoload :Schedule, "#{dir}/calendar_resource.rb"
  end
end
