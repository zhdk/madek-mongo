# Instead of the standard composition, convert everything
# non-alpha and non-digit to dash and squeeze
class String
  def identify
    if Mongoid.parameterize_keys
      gsub(/[^a-z0-9]+/i, ' ').strip.gsub(' ', '-').downcase
    else
      self
    end
  end
end
