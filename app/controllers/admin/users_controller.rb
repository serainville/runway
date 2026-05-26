module Admin
  class UsersController < BaseController
    def index
      @users = User.order(:email)
    end

    def update
      user = User.find(params[:id])
      result = Admin::Users::UpdateUser.call(actor: current_user, user: user, params: user_params)

      if result.success?
        redirect_to admin_users_path, notice: "User updated"
      else
        redirect_to admin_users_path, alert: result.message
      end
    end

    def reset_password
      user = User.find(params[:id])
      result = Admin::Users::ResetPassword.call(
        actor: current_user,
        user: user,
        password: reset_password_params[:password],
        password_confirmation: reset_password_params[:password_confirmation]
      )

      if result.success?
        redirect_to admin_users_path, notice: "User password reset"
      else
        redirect_to admin_users_path, alert: result.message
      end
    end

    private

    def user_params
      params.require(:user).permit(:role)
    end

    def reset_password_params
      params.require(:password_reset).permit(:password, :password_confirmation)
    end
  end
end
