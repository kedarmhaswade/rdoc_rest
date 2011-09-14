# The Foo Controller docs
# :class_name: Foo's Custom Name
# :path: /foo
class FooController
  # This is a test API
  # :path: /apple
  # :http_req: POST
  # :api_status: public
  def apple

  end

  # This is a test API that won't show up because it's not public
  # :path: /dog
  # :http_req: DELETE
  # :api_status: private
  def dog
  end
end