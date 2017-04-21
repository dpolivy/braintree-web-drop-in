require_relative "helpers/paypal_helper"
require_relative "helpers/drop_in_helper"
require_relative "helpers/skip_browser_helper"

HOSTNAME = `hostname`.chomp
PORT = 4567

describe "Drop-in" do
  include SkipBrowser
  include DropIn
  include PayPal

  describe "setup" do
    it "requires a selector" do
      visit "http://#{HOSTNAME}:#{PORT}?selector=null"

      expect(find("#error")).to have_content("options.selector is required.")
    end

    it "requires authorization" do
      visit "http://#{HOSTNAME}:#{PORT}?authorization=null"

      expect(find("#error")).to have_content("options.authorization is required.")
    end

    it "does not setup paypal when not configured" do
      visit "http://#{HOSTNAME}:#{PORT}?paypal=null&paypalCredit=null"

      expect(page).not_to have_selector(".braintree-option__paypal")
      expect(page).to have_content("Card Number")
      expect(page).to have_content("Expiration Date")
    end

    it "supports locale" do
      visit "http://#{HOSTNAME}:#{PORT}?locale=es_ES"

      expect(page).to have_content("Tarjeta")
    end
  end

  describe "payment option priority" do
    it "uses default priority of card, paypal, paypalCredit" do
      visit "http://#{HOSTNAME}:#{PORT}"

      find(".braintree-heading")
      payment_options = all(:css, ".braintree-option__label")

      expect(payment_options[0]).to have_content("Card")
      expect(payment_options[1]).to have_content("PayPal")
      expect(payment_options[2]).to have_content("PayPal Credit")
    end

    it "uses custom priority of paypal, card, paypalCredit" do
      options = '["paypal","card","paypalCredit"]'
      visit URI.encode("http://#{HOSTNAME}:#{PORT}?paymentOptionPriority=#{options}")

      find(".braintree-heading")
      payment_options = all(:css, ".braintree-option__label")

      expect(payment_options[0]).to have_content("PayPal")
      expect(payment_options[1]).to have_content("Card")
      expect(payment_options[2]).to have_content("PayPal Credit")
    end

    it "shows an error when an unrecognized payment option is specified" do
      options = '["dummy","card"]'
      visit URI.encode("http://#{HOSTNAME}:#{PORT}?paymentOptionPriority=#{options}")

      expect(find("#error")).to have_content("paymentOptionPriority: Invalid payment option specified.")
    end
  end

  describe "tokenizes" do
    it "a card" do
      visit "http://#{HOSTNAME}:#{PORT}"

      click_option("card")
      hosted_field_send_input("number", "4111111111111111")
      hosted_field_send_input("expirationDate", "1019")
      hosted_field_send_input("cvv", "123")

      submit_pay

      expect(find(".braintree-heading")).to have_content("Paying with")

      # Drop-in Details
      expect(page).to have_content("Ending in ••11")

      # Nonce Details
      expect(page).to have_content("CreditCard")
      expect(page).to have_content("ending in 11")
      expect(page).to have_content("Visa")
    end

    it "PayPal" do
      visit "http://#{HOSTNAME}:#{PORT}"

      click_option("paypal")

      open_popup_and_complete_login

      submit_pay

      expect(find(".braintree-heading")).to have_content("Paying with PayPal")

      expect(page).to have_content("PayPalAccount")
      expect(page).to have_content(ENV["PAYPAL_USERNAME"])
    end

    it "PayPal Credit" do
      visit "http://#{HOSTNAME}:#{PORT}"

      click_option("paypalCredit")

      open_popup_and_complete_login do
        expect(page).to have_content("PayPal Credit");
      end

      submit_pay

      expect(find(".braintree-heading")).to have_content("Paying with PayPal")

      expect(page).to have_content("PayPalAccount")
      expect(page).to have_content(ENV["PAYPAL_USERNAME"])
    end
  end
end