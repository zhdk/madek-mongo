# -*- encoding : utf-8 -*-
module Upload
  class Estimation
    def self.call(env)
      [200, {"Content-Type" => "text/html"}, [""]]
    end
  end
end
