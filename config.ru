require_relative 'app/app'
require_relative 'app/image_library'

app = Focal::App
app.opts[:image_library] = Focal::ImageLibrary.new(ENV['FOCAL_IMAGE_LIBRARY'])
app.opts[:x_accel] = !ENV['FOCAL_X_ACCEL'].nil?
run app
