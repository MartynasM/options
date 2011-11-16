class GitResult
  attr_accessor :errors, :warnings
  
  def initialize(stop_on_warnings)
    @errors = []
    @warnings = []
    @stop_on_warnings = stop_on_warnings
  end

  def continue?
    !(@errors.size > 0 or (@warnings.size > 0 and @stop_on_warnings))
  end

  def warnings?
  	@warnings.size > 0 
  end

  def errors?
  	@errors.size > 0 
  end

  def perfect_commit?
  	!(errors? || warnings?)
  end
end
