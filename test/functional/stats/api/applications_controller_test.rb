# frozen_string_literal: true

require 'test_helper'

class Stats::Api::ApplicationsControllerTest < ActionController::TestCase
  test 'routes' do
    assert_routing({ method: :get, path: '/stats/api/applications/42/usage.json' },
                   { application_id: '42', action: 'usage', format: 'json', controller: 'stats/api/applications' })
  end

  def test_summary
    setup_data(login_as: :buyer)

    get :summary, params: { format: :json, application_id: @app.id }

    assert_equal 200, response.status
  end

  test 'csv format for errors' do
    setup_data

    get :usage, params: { format: :csv, application_id: @app.id, period: 'troloro' }
    assert_match /text\/plain/, response.header['Content-Type']
    assert_equal 400, response.status

    get :usage_response_code, params: { format: :csv, application_id: @app.id, period: 'troloro' }
    assert_match /text\/plain/, response.header['Content-Type']
    assert_equal 400, response.status
  end

  private

  # setup_data instead of setup because "should route" run "setup" each time
  def setup_data(login_as: :provider)
    @provider = FactoryBot.create(:provider_account)
    @buyer    = FactoryBot.create(:buyer_account, provider_account: @provider, timezone: 'Mountain Time (US & Canada)')
    @app_plan = FactoryBot.create(:application_plan, issuer: @provider.default_service)
    @app      = @buyer.buy! @app_plan

    @request.host = @provider.admin_domain

    case login_as
    when :provider
      login_provider @provider
    when :buyer
      login_buyer @buyer
    end
  end
end
