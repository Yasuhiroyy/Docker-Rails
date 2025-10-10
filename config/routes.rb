Rails.application.routes.draw do
  get "static_pages/home"

  get  'login',  to: 'sessions#new'
  post 'login',  to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  root 'static_pages#home' 

end