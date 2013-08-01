class Spree::Admin::DropShipOrdersController < Spree::Admin::ResourceController

  before_filter :load_order, :only =>[:new, :create]

  def create
    @drop_ship_order = @order.drop_ship_orders.build(params[:drop_ship_order])
    @drop_ship_order.sent_at = Time.now
    @drop_ship_order.confirmed_at = Time.now
    @drop_ship_order.state = "confirmed"

    if @drop_ship_order.save
      flash[:success] = flash_message_for(@drop_ship_order, :successfully_created)
      respond_with(@drop_ship_order) do |format|
        format.html { redirect_to admin_order_drop_ship_orders_path(@order) }
      end
    else
      respond_with(@drop_ship_order) { |format| format.html { render :action => 'new' } }
    end
  end

  def disp
    @drop_ship_order = Spree::DropShipOrder.find(params[:id])

    if params[:drop_ship_order] or params[:shipment_tracking_number]
      order = @drop_ship_order.order

      order.shipments.ready.each do |shipment|
        shipment.tracking = params[:shipment_tracking_number]
        shipment.ship
      end

      @drop_ship_order.update_attribute(:shipped_at, Time.now)
      @drop_ship_order.update_attribute(:state, "complete")

      redirect_to admin_drop_ship_orders_path
    end
  end

  def show
    @dso = load_resource
    @supplier = @dso.supplier
    @address = @dso.order.ship_address
  end
  
  def deliver
    @dso = load_resource
    if @dso.deliver
      flash[:notice] = "Drop ship order ##{@dso.id} was successfully sent!"
    else
      flash[:error] = "Drop ship order ##{@dso.id} could not be sent."
    end
    redirect_to admin_drop_ship_order_path(@dso)
  end
 
  private

    def collection
      params[:q] ||= {}
      params[:q][:meta_sort] ||= "id.desc"
      scope = if params[:supplier_id] && @supplier = Spree::Supplier.find(params[:supplier_id])
        @supplier.orders
      elsif params[:order_id] && @order = Spree::Order.find_by_number(params[:order_id])
        @order.drop_ship_orders
      else
        Spree::DropShipOrder.scoped
      end
      @search = scope.includes(:supplier).search(params[:q])
      @collection = @search.result.page(params[:page]).per(Spree::Config[:orders_per_page])
    end

    def load_order
      @order = Spree::Order.find_by_number(params[:order_id])
    end

end
