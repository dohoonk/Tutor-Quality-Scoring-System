class AddRefreshFunctionsForMaterializedViews < ActiveRecord::Migration[8.0]
  def up
    # Create a function to refresh both materialized views
    execute <<-SQL
      CREATE OR REPLACE FUNCTION refresh_tutor_stats()
      RETURNS void AS $$
      BEGIN
        REFRESH MATERIALIZED VIEW CONCURRENTLY tutor_stats_7d;
        REFRESH MATERIALIZED VIEW CONCURRENTLY tutor_stats_14d;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    execute "DROP FUNCTION IF EXISTS refresh_tutor_stats()"
  end
end
