class OrdersController < ApplicationController
  before_action :set_store
  before_action :set_order, only: [:show, :edit, :update, :destroy]

  # GET /orders
  # GET /orders.json
  def index
    @orders_of_today = @store.orders.where(:created_at => Time.now.beginning_of_day..Time.now.end_of_day)
    @orders_of_yesterday = @store.orders.where(:created_at => Time.now.yesterday.beginning_of_day..Time.now.yesterday.end_of_day)
    @orders_of_this_month = @store.orders.where(:created_at => Time.now.beginning_of_month..Time.now.end_of_month)
  end

  # GET /orders/1
  # GET /orders/1.json
  def show
  end

  # GET /orders/new
  def new
    @order = @store.orders.build
  end

  # GET /orders/1/edit
  def edit
  end

  # POST /orders
  # POST /orders.json
  def create
    p = params[:order]

    if user_signed_in?
      @user = User.find(p[:user_attributes][:id])
      @user.update_attributes!(p[:user_attributes])
      p.delete(:user_attributes)
      @order = Order.new(p)
      @order.user = @user
    else
      @order = Order.new order_params
    end

    if @order.user.email.blank? && @order.user.password.blank? && @order.user.password_confirmation.blank?
      @order.user.email = "guest_#{Time.now.to_i}#{rand(99)}@meals4.me"
      @order.user.password = "guest_password"
      @order.user.password_confirmation = "guest_password"
      #@order.user.skip_confirmation! # Skip sending emails
    end

    # Need to validate the phone number for the order
    #@order.user.validate_phone = true

    # Set the status of this order
    @order.transfer_status = "unconfirmed"

    respond_to do |format|
      if @order.save
        # Clear the cart in the session
        session.delete "cart_id_for_store_id_#{@order.store_id}"

        if @order.payment_type == 'paypal'
          # Redirect to Paypal Page
          format.html { redirect_to @order.paypal_url }
        else
          # Send Fax through Interfax
          #@order.to_fax

          #format.html { redirect_to store_order_url(@store, @order), notice: 'Order was successfully created.' }
          format.html { redirect_to q_store_order_success_url, notice: 'Order was successfully created.' }
          format.json { render json: @order, status: :created, location: @order }
        end
      else
        @cart = current_cart(@order.store_id, false)
        @order.user.email = ""

        #format.html { render action: "new" }
        format.html { redirect_to q_store_order_failure_url(@store, @order), notice: 'Order was successfully created.' }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /orders/1
  # PATCH/PUT /orders/1.json
  def update
    respond_to do |format|
      if @order.update(order_params)
        format.html { redirect_to store_order_url(@store, @order), notice: 'Order was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /orders/1
  # DELETE /orders/1.json
  def destroy
    @order.destroy
    respond_to do |format|
      format.html { redirect_to orders_url }
      format.json { head :no_content }
    end
  end

  private

    def set_store
      @store = Store.find(params[:store_id])
    end

  # Use callbacks to share common setup or constraints between actions.
    def set_order
      @order = Order.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def order_params
      params.require(:order).permit(:note, :payment_type, :payment_status, :transfer_status, :tip, :store_id, :cart_id, :user_id,
                                    :user_attributes => [:id, :firstname, :lastname, :phone, :address_attributes => [:id, :address1, :address2, :city]])
    end
end