# frozen_string_literal: true

require 'ffi'
require 'selenium-webdriver'
require 'capybara'
require 'capybara/dsl'
require 'win32/sound'
require 'yaml'
require_relative 'url_builder'

class Bot
  include UrlBuilder
  include Win32
  include Capybara::DSL
  attr_reader :config

  def initialize_firefox_driver
    profile = Selenium::WebDriver::Firefox::Profile.new

    Capybara.register_driver :imageless_firefox do |app|
      Capybara::Selenium::Driver.new(app, :browser => :firefox, :profile => profile)
    end
  end

  def initialize
    initialize_firefox_driver
    Selenium::WebDriver::Firefox::Service.driver_path = "geckodriver.exe"
    Capybara.default_driver = :imageless_firefox
    @config = YAML.load(File.read('config.yaml'))
  end

  def scan
    loop do
      visit store_url(config['location'], config['card'])
      return if config['mode'] == 'debug'
      sleep_until_exists('.total-products-text')

      text = find('.featured-container-xl')&.text || find('.featured-container-lg')&.text
      unless text.downcase.include?('out of stock')
        Sound.beep(300,250)
        if config['mode'] == 'minimal'
          sleep(600) # 10 mins to complete the purchase before browser window closes
          return
        end
        add_to_cart
        handle_checkout
        go_to_summary
        sleep(600)
        return
      end
      wait_before_reloading
    end
  end

  def wait_before_reloading
    average_time = config['refresh_time']
    minimum = average_time.to_i / 2
    maximum = average_time.to_i  + minimum
    sleep(rand(minimum..maximum))
  end

  def add_to_cart
    click_on(class: 'js-add-button')
    sleep_until_exists('.js-checkout')
    find('.js-checkout').click
  end

  def handle_checkout
    if !page.has_css?('#billingName1') && !page.has_css?('#btnCheckoutAsGuest')
      sleep(0.1)
    end
    if page.has_css?('#btnCheckoutAsGuest')
      find('#btnCheckoutAsGuest').click
    end
    fill_in 'billingName1', with: config['address']['first_name']
    fill_in 'billingName2', with: config['address']['last_name']
    fill_in 'billingPhoneNumber', with: config['address']['phone_number']
    fill_in 'email', with: config['address']['email']
    fill_in 'verEmail', with: config['address']['email']
    fill_in 'billingAddress1', with: config['address']['street']
    fill_in 'billingAddress2', with: config['address']['apartment_number']
    fill_in 'billingCity', with: config['address']['city']
    fill_in 'billingPostalCode', with: config['address']['postal_code']
    begin
      fill_in 'billingState', with: config['address']['state'] # not all areas have this
    rescue
    end
    fill_in 'ccNum', with: config['payment']['card_number']
    fill_in 'cardSecurityCode', with: config['payment']['cvv']
    find("#expirationDateMonth option[value='#{config['payment']['expiration_month']}']").select_option
    find("#expirationDateYear option[value='#{config['payment']['expiration_year']}']").select_option
  end

  def go_to_summary
    find('#dr_siteButtons input.dr_button').click
  end

  def sleep_until_exists(selector)
    slept_for = 0
    while !page.has_css?(selector)
      slept_for += 0.1
      sleep(0.1)
    end
  end
end


p Time.now
Bot.new.scan