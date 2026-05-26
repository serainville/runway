module Admin
  class BaseController < ApplicationController
    before_action :require_current_user!
    before_action :require_admin!
  end
end
