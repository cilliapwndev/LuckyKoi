Gem::Specification.new do |s|
  s.name        = 'luckykoi'
  s.version     = '0.1.0'
  s.summary     = "Sovereign Architect Financial Tracker"
  s.description = "A visual financial management tool with mission-based tracking."
  s.authors     = ["Mark Angelo P. Santonil"]
  s.email       = 'cillia2203@gmail.com'
  s.files       = Dir["lib/**/*.rb", "bin/*"]
  s.executables << 'lucky_koi'
  s.license     = 'MIT'

  # Dependencies
  s.add_runtime_dependency 'glimmer-dsl-libui'
  s.add_runtime_dependency 'json'
end
