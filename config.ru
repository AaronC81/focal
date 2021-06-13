require_relative 'app/app'
require_relative 'app/image_library'

app = Focal::App
app.set :image_library, Focal::ImageLibrary.new(ENV['FOCAL_IMAGE_LIBRARY'])
app.set :x_accel, !ENV['FOCAL_X_ACCEL'].nil?
run app
