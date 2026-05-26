class SessionsController < ApplicationController
  def new
    if authenticated?
      redirect_to dashboard_path, notice: "You are already signed in"
      return
    end
  end

  def create
    result = Authentication::SignInUser.call(username: session_params[:username], password: session_params[:password])

    if result.success?
      reset_session
      session[:user_id] = result.user.id
      redirect_to dashboard_path, notice: "Welcome back"
      return
    end

    flash.now[:alert] = result.message
    render :new, status: :unprocessable_entity
  end

  def destroy
    Authentication::SignOutUser.call(user: current_user)
    reset_session
    redirect_to root_path, notice: "You have been signed out"
  end

  private

  def session_params
    params.require(:session).permit(:username, :password)
  end
end
