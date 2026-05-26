class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  helper_method :current_user, :authenticated?

  private

  def current_user
    @current_user ||= begin
      session_user_id = session[:user_id]
      header_user_id = request.headers["X-Runway-User-Id"]
      user_id = session_user_id.presence || header_user_id.presence
      User.find_by(id: user_id)
    end
  end

  def authenticated?
    current_user.present?
  end

  def require_current_user!
    return if current_user

    respond_to do |format|
      format.json { render json: { error: "Authentication required" }, status: :unauthorized }
      format.any do
        redirect_to new_session_path, alert: "Please sign in to continue"
      end
    end
  end

  def require_current_user_json!
    return if current_user

    render json: { error: "Authentication required" }, status: :unauthorized
  end
end
