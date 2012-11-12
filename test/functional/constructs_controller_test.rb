require 'test_helper'

class ConstructsControllerTest < ActionController::TestCase
  setup do
    @construct = constructs(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:constructs)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create construct" do
    assert_difference('Construct.count') do
      post :create, construct: { design_id: @construct.design_id, name: @construct.name, seq: @construct.seq }
    end

    assert_redirected_to construct_path(assigns(:construct))
  end

  test "should show construct" do
    get :show, id: @construct
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @construct
    assert_response :success
  end

  test "should update construct" do
    put :update, id: @construct, construct: { design_id: @construct.design_id, name: @construct.name, seq: @construct.seq }
    assert_redirected_to construct_path(assigns(:construct))
  end

  test "should destroy construct" do
    assert_difference('Construct.count', -1) do
      delete :destroy, id: @construct
    end

    assert_redirected_to constructs_path
  end
end
