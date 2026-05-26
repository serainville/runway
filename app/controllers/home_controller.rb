class HomeController < ApplicationController
  skip_before_action :require_current_user!, raise: false

  def index
  end
end
