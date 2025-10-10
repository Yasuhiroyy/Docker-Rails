class SessionsController < ApplicationController
  def new
    # ログインフォーム表示
  end

  def create
    # ログインフォームから送られた email と password を受け取ってログイン処理
    user = User.find_by(email: params[:session][:email].downcase)
    if user&.authenticate(params[:session][:password])
      session[:user_id] = user.id
      flash[:success] = "ログインしました"
      redirect_to root_path
    else
      flash.now[:danger] = "メールアドレスまたはパスワードが正しくありません"
      render :new
    end
  end

  def destroy
    #ログアウト処理
    session.delete(:user_id)
    flash[:success] = "ログアウトしました"
    redirect_to root_path
  end
end

