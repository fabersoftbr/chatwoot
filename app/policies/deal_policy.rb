class DealPolicy < ApplicationPolicy
  def index?
    true
  end

  def board?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def move?
    true
  end

  def destroy?
    @account_user.administrator?
  end
end
