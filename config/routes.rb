# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

resources :webforms do
  member do
    post 'new_issue'
  end
end
