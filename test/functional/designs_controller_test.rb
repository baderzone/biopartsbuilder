require 'test_helper'

class DesignsControllerTest < ActionController::TestCase
  setup do
    @design = designs(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:designs)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create design" do
    assert_difference('Design.count') do
      post :create, design: { part_id: @design.part_id, protocol_id: @design.protocol_id, user_id: @design.user_id }
    end

    assert_redirected_to design_path(assigns(:design))
  end

  test "should show design" do
    get :show, id: @design
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @design
    assert_response :success
  end

  test "should update design" do
    put :update, id: @design, design: { part_id: @design.part_id, protocol_id: @design.protocol_id, user_id: @design.user_id }
    assert_redirected_to design_path(assigns(:design))
  end

  test "should destroy design" do
    assert_difference('Design.count', -1) do
      delete :destroy, id: @design
    end

    assert_redirected_to designs_path
  end
end
