#ログイン状態を扱う
class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?

  private
  
  #セッションに保存された user_id から DB を検索して、現在ログインしているユーザーを返す
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  #ログインしているかどうかを判定する
  def logged_in?
    current_user.present?
  end

  #ログインしていなければ、ログインページにリダイレクトする
  def require_login
    unless logged_in?
      flash[:warning] = "ログインしてください"
      redirect_to login_path
    end
  end
end