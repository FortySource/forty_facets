class Minitest::Test
  def wrap_in_db_transaction(&block)
    ActiveRecord::Base.transaction do
      yield
      raise ActiveRecord::Rollback
    end
  end
end
