# frozen_string_literal: true

module ApiHelpers
  def self.parse_pagination_params(params)
    page = (params['page'] || 1).to_i
    per_page = (params['per_page'] || 50).to_i
    per_page = 100 if per_page > 100
    per_page = 1 if per_page < 1
    [page, per_page]
  end

  def self.parse_filter_params(params, allowed_keys)
    allowed_keys.each_with_object({}) do |key, hash|
      hash[key] = params[key] if params[key]
    end
  end

  def self.paginate_dataset(dataset, page, per_page)
    total = dataset.count
    items = dataset.limit(per_page, (page - 1) * per_page).all
    {
      items: items,
      pagination: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
    }
  end

  def self.error_response(message, status = 400)
    response.status = status
    { error: message }
  end

  def self.not_found_response(resource, id)
    response.status = 404
    { error: "#{resource} '#{id}' not found" }
  end
end
