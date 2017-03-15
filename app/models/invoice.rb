class Invoice < ActiveRecord::Base
  enum status: [:unpaid, :paid, :voided]

  belongs_to :contact
  belongs_to :currency
  has_many :line_items, dependent: :destroy

  validates :contact, presence: true
  validates :line_items, presence: true
  validates :currency, presence: true
  validates :date, presence: true
  validates :number, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than: 0 }
  validates :discount_in_percents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 100 }
  validates :status, inclusion: { in: statuses.keys }
  validates :zero_rated_gst, inclusion: { in: [ true, false ] }
  validate :gst_applies_to_nzd_only

  # when PDF is generated, save it on filesystem and don't regenerate

  def undiscounted_total
    line_items.map(&:total).sum
  end

  def discount
    undiscounted_total * (discount_in_percents / 100.to_d)
  end

  def discounted_total
    undiscounted_total - discount
  end

  def gst
    if zero_rated_gst?
      0
    else
      discounted_total * 0.15.to_d
    end
  end

  def total
    discounted_total + gst
  end

  def total_in_nzd
    total * currency.conversion_rate(date).rate
  end

  private
  def gst_applies_to_nzd_only
    if !zero_rated_gst? && currency.code != 'NZD'
      errors.add(:base, 'GST can be applied to invoices in NZD only')
    end
  end
end
