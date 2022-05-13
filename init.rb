# Redmine Web Forms - A Redmine Plugin
# Copyright (C) 2022  Frederico Camara
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

Redmine::Plugin.register :redmine_web_forms do
  name 'Redmine Web Forms plugin'
  author 'Frederico Camara'
  description 'This is a plugin for Redmine'
  version '1.0.0'
  url 'https://github.com/fredsdc/redmine_web_forms'
  author_url 'https://github.com/fredsdc'

  menu :admin_menu, :webforms, { controller: 'webforms', action: 'index'},
  caption: :label_webform_plural, html: { class: 'icon icon-document'}
end
