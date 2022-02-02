# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

resources :webforms do
  collection do
    post 'update_selects'
  end

  member do
    post 'new_issue'
  end
end
