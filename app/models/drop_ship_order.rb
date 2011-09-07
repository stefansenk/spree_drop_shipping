class DropShipOrder < ActiveRecord::Base
  
  #==========================================
  # Associations
  
  belongs_to :order
  belongs_to :supplier
  has_many   :line_items, :class_name => "DropShipLineItem"
  
  #==========================================
  # Validations
  
  validates :supplier_id, :order_id, :presence => true

  #==========================================
  # Callbacks
  
  before_save :update_total

  #==========================================
  # State Machine
  
  state_machine :initial => 'active' do
  
    before_transition :on => :deliver, :do => :perform_delivery
    before_transition :on => :confirm, :do => :perform_confirmation
    before_transition :on => :ship,    :do => :perform_shipment
  
    event :deliver do
      transition :active => :sent
    end
  
    event :confirm do
      transition :sent => :confirmed
    end
    
    event :ship do
      transition :confirmed => :complete
    end 
    
    state :complete do
      validates :shipping_method, :confirmation_number, :tracking_number, :presence => true 
    end
    
  end
  
    
  #==========================================
  # Instance Methods  
  
  # Adds line items to the drop ship order. This method will group similar line items
  # and update quantities as necessary. You can add a single line item or an array of
  # line items.
  def add(new_items)
    new_items = [ new_items ].flatten.reject{|li| li.supplier_id.nil? || li.supplier_id != self.supplier_id }
    attributes = []
    new_items.group_by(&:variant_id).each do |variant_id, items|
      quantity = items.map(&:quantity).inject(:+)
      if item = self.line_items.find_by_variant_id(variant_id)
        item.update_attributes(:quantity => item.quantity + quantity)
      else
        attributes << items.first.drop_ship_attributes.update(:quantity => quantity)
      end
    end    
    self.line_items.create(attributes) unless attributes.empty?
    self.save ? self : nil
  end
  
  # Updates the drop ship order's total by getting the sum of its line items' subtotals
  def update_total
    self.total = self.line_items.reload.map(&:subtotal).inject(:+).to_f
  end
  
  # Don't allow drop ship orders to be destroyed
  def destroy
    false
  end
  
  
  #==========================================
  # Private Methods
  
  private
  
    def perform_delivery # :nodoc:
      self.sent_at = Time.now
      DropShipOrderMailer.supplier_order(self).deliver!
    end
    
    def perform_confirmation # :nodoc:
      self.confirmed_at = Time.now
      DropShipOrderMailer.confirmation(self).deliver!
    end
    
    def perform_shipment # :nodoc:
      self.shipped_at = Time.now
      DropShipOrderMailer.shipment(self).deliver!
    end  

end
