class AccountsController < ApplicationController
  before_action :require_current_user!

  def show
  end

  def password
    result = Authentication::ChangePassword.call(
      actor: current_user,
      current_password: password_params[:current_password],
      new_password: password_params[:password],
      new_password_confirmation: password_params[:password_confirmation]
    )

    if result.success?
      redirect_to account_path, notice: "Password updated"
    else
      redirect_to account_path, alert: result.message
    end
  end

  private

  def password_params
    params.require(:account).permit(:current_password, :password, :password_confirmation)
  end
end
