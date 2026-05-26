class RegistrationsController < ApplicationController
  def new
    if authenticated?
      redirect_to dashboard_path, notice: "You are already signed in"
      return
    end
  end

  def create
    result = Authentication::RegisterUser.call(params: registration_params)

    if result.success?
      reset_session
      session[:user_id] = result.user.id
      redirect_to dashboard_path, notice: "Your account has been created"
      return
    end

    flash.now[:alert] = result.message
    render :new, status: :unprocessable_entity
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
