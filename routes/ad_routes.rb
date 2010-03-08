get '/ad/:ad_name/?' do |ad_name|
    @ad_name = ad_name
    haml :ad, :layout => false
end

