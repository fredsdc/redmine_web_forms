Redmine::Plugin.register :redmine_web_forms do
  name 'Redmine Web Forms plugin'
  author 'Frederico Camara'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'https://github.com/fredsdc/redmine_web_forms'
  author_url 'https://github.com/fredsdc'

  menu :admin_menu, :webforms, { controller: 'webforms', action: 'index'},
  caption: :label_webform_plural, html: { class: 'icon icon-document'}
end
