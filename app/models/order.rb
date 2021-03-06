class Order < ActiveRecord::Base
  #All Attributes:
  #========================================================================
  #class CreateOrders < ActiveRecord::Migration
  #  def change
  #    create_table :orders do |t|
  #      t.string :note
  #      t.string :invoice
  #      t.string :payment_type, :default => 'cash', :null => false
  #      t.string :payment_status, :default => 'not_paid', :null => false
  #      t.string :transfer_status
  #      t.decimal :tip, :default => 0, :precision => 8, :scale => 2
  #      t.references :store, index: true
  #      t.references :cart, index: true
  #      t.references :user, index: true
  #
  #      t.timestamps
  #    end
  #  end
  #end

  validates :tip, presence: true, numericality: { greater_than_or_equal_to: 0 }

  belongs_to :cart

  # As a Join Table for stores and users
  belongs_to :store
  belongs_to :user
  accepts_nested_attributes_for :user

  # In order to use number_to_currency
  include ActionView::Helpers::NumberHelper
  extend ActionView::Helpers::NumberHelper
  include Rails.application.routes.url_helpers

  # Solve One-Two-One association's create_model_and_update_nested_model Problem
  # Test on 2014-06-10, Still Necessary for Creating Orders
  def user_attributes=(attributes)
    if attributes['id'].present?
      self.user = User.find(attributes['id'])
    end
    super
  end

  PAYMENT_TYPE_OPTIONS = [['Cash ', 'cash'], ['PayPal ', 'paypal']]
  TIP_OPTIONS = [['Tip cash', 0], ['Tip $1.00', 1], ['Tip $2.00', 2], ['Tip $3.00', 3], ['Tip $4.00', 4], ['Tip $5.00', 5],
               ['Tip $6.00', 6], ['Tip $7.00', 7], ['Tip $8.00', 8], ['Tip $9.00', 9], ['Tip $10.00', 10]]

  def paypal_url
    if APP_CONFIG["ibm_mode"] == "test"
      paypal_email = 'wanfenghuaian-facilitator@hotmail.com'
    elsif APP_CONFIG['ibm_mode'] == "production"
      paypal_email = store.get_paypal_account
    end

    values = {
        :business       => paypal_email,
        :cancel_return  => q_store_home_url(:host => store.domain),
        :charset        => 'utf-8',
        :cmd            => '_cart',
        :currency_code  => 'USD',
        :custom         => '',
        #:image_url      => "https://meals4.me/assets/mfm_logo.png",
        :invoice        => id,
        :lc             => 'US',
        :no_shipping    => 0,
        :no_note        => 1,
        :notify_url     => q_order_paypal_notify_url(:host => store.domain),
        :num_cart_items => cart.cart_items.size,
        :return         => q_store_home_url(:host => store.domain),
        :rm             => 2,
        :secret         => 'hello_token',
        :tax_cart       => number_with_precision(cart.tax, :precision => 2),
        :upload         => 1,
    }

    cart.cart_items.each_with_index do |item, index|
      values.merge!({
                        "amount_#{index+1}" => item.price,
                        "discount_rate_#{index+1}" => 0,
                        "item_name_#{index+1}" => item.name,
                        "item_number_#{index+1}" => item.id,
                        "quantity_#{index+1}" => item.quantity,
                        "shipping_#{index+1}" => 0
                    })
    end

    cart_size = cart.cart_items.size
    values.merge!({
                      "amount_#{cart_size+1}" => cart.delivery_fee,
                      "discount_rate_#{cart_size+1}" => 0,
                      "item_name_#{cart_size+1}" => 'Delivery fee',
                      "item_number_#{cart_size+1}" => '',
                      "quantity_#{cart_size+1}" => 1,
                      "shipping_#{cart_size+1}" => 0,

                      "amount_#{cart_size+2}" => tip,
                      "discount_rate_#{cart_size+2}" => 0,
                      "item_name_#{cart_size+2}" => 'Tip',
                      "item_number_#{cart_size+2}" => '',
                      "quantity_#{cart_size+2}" => 1,
                      "shipping_#{cart_size+2}" => 0
                  })

    if APP_CONFIG["ibm_mode"] == "test"
      APP_CONFIG['paypal_sandbox_base_url'] + "?" + values.to_query
    elsif APP_CONFIG['ibm_mode'] == "production"
      APP_CONFIG['paypal_base_url'] + "?" + values.to_query
    end
  end

  # Use class method because of delayed_job
  def to_fax
    template = ERB.new(File.open(Rails.root.join('app/views/orders/_fax.html.erb')).read)
    str = template.result(binding)
    client = Savon.client(log: false, wsdl: APP_CONFIG["interfax_url"])  # Turn off log for security

    if APP_CONFIG["ibm_mode"] == "test"
      fax_number = '9790000000'
    elsif APP_CONFIG["ibm_mode"] == "production"
      fax_number = self.store.fax
    end

    if store.has_fax?
      usr = store.fax_usr
      pwd = store.fax_pwd
    else
      usr = APP_CONFIG["interfax_usr"]
      pwd = APP_CONFIG["interfax_pwd"]
    end

    response_interfax = client.call(:send_char_fax, :message => {'Username' => usr, 'Password' => pwd,
                                                                 'FaxNumber' => fax_number, 'Data' => str, 'FileType' => 'HTML'})

    if response_interfax.body[:send_char_fax_response][:send_char_fax_result].to_i > 0
      # Fax succeed
      self.transfer_status= "good_fax"
    else
      # Fax failed
      self.transfer_status= "bad_fax"
    end
    self.save
  end

end
