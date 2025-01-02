# Business Request 1 : City Level Fare and Trip Summary Report
WITH total AS(
SELECT 	 city_id, 
         COUNT(trip_id) AS city_total_trips,
         SUM(fare_amount) AS total_fare,
         SUM(distance_travelled_km) AS total_distance,
         SUM(COUNT(trip_id)) OVER () AS contribution_to_total_trips
FROM 	 trips_db.fact_trips
GROUP BY city_id
)
SELECT   c.city_name, 
		 city_total_trips, 
		 ROUND((total_fare/total_distance),1) AS avg_fare_per_km,
		 ROUND((total_fare/city_total_trips),1) AS avg_fare_per_trip,
		 CONCAT(ROUND((city_total_trips*100/contribution_to_total_trips),1) , '%') AS contribution_to_total_trips
FROM 	 total AS t
JOIN 	 trips_db.dim_city AS c ON t.city_id = c.city_id
ORDER BY city_total_trips DESC; 



# Business Request 2 : Monthly City Level Trips Target Performance Report
WITH actual_trips AS (
SELECT 		d.start_of_month,
			d.month_name,
			city.city_id, 
			COUNT(trip.trip_id) AS total_actual_trips
FROM 		trips_db.fact_trips AS trip
JOIN 		trips_db.dim_city AS city ON trip.city_id = city.city_id
INNER JOIN 	trips_db.dim_date AS d ON trip.date = d.date
GROUP BY 	d.start_of_month, d.month_name, city.city_id
) 
SELECT 	 	city_name, 
			month_name,
			total_actual_trips,
			total_target_trips,
			(CASE WHEN total_actual_trips > total_target_trips 
					THEN "Above Target"
				  ELSE "Below Target"
			 END) AS performance_status,
			CONCAT(ROUND(((total_actual_trips-total_target_trips)*100)/total_actual_trips,1) , '%') AS performance_gap
FROM 		targets_db.monthly_target_trips AS target
JOIN 		actual_trips ON 
					(target.city_id = actual_trips.city_id)
				AND (target.month = actual_trips.start_of_month)
JOIN 		trips_db.dim_city AS city ON
					target.city_id = city.city_id
ORDER BY	city_name, performance_status, total_actual_trips DESC;
    
 
 
# Business Request 3 : City Level Repeat Passenger Trip Frequency Report
SELECT   city_name,  
		 SUM(repeat_passenger_count) AS total,
		 CONCAT(ROUND((SUM(CASE WHEN trip_count="2-Trips" THEN repeat_passenger_count END)*100)/SUM(repeat_passenger_count),1), '%') AS "2-Trips",
         CONCAT(ROUND((SUM(CASE WHEN trip_count="3-Trips" THEN repeat_passenger_count END)*100)/SUM(repeat_passenger_count),1), '%') AS "3-Trips",
         CONCAT(ROUND((SUM(CASE WHEN trip_count="4-Trips" THEN repeat_passenger_count END)*100)/SUM(repeat_passenger_count),1), '%') AS "4-Trips",
         CONCAT(ROUND((SUM(CASE WHEN trip_count="5-Trips" THEN repeat_passenger_count END)*100)/SUM(repeat_passenger_count),1), '%') AS "5-Trips",
         CONCAT(ROUND((SUM(CASE WHEN trip_count="6-Trips" THEN repeat_passenger_count END)*100)/SUM(repeat_passenger_count),1), '%') AS "6-Trips",
         CONCAT(ROUND((SUM(CASE WHEN trip_count="7-Trips" THEN repeat_passenger_count END)*100)/SUM(repeat_passenger_count),1), '%') AS "7-Trips",
         CONCAT(ROUND((SUM(CASE WHEN trip_count="8-Trips" THEN repeat_passenger_count END)*100)/SUM(repeat_passenger_count),1), '%') AS "8-Trips",
         CONCAT(ROUND((SUM(CASE WHEN trip_count="9-Trips" THEN repeat_passenger_count END)*100)/SUM(repeat_passenger_count),1), '%') AS "9-Trips",
         CONCAT(ROUND((SUM(CASE WHEN trip_count="10-Trips" THEN repeat_passenger_count END)*100)/SUM(repeat_passenger_count),1), '%') AS "10-Trips"
FROM 	 trips_db.dim_repeat_trip_distribution as trip
JOIN 	 trips_db.dim_city AS city ON trip.city_id = city.city_id
GROUP BY city_name
ORDER BY total DESC;



# Business Request 4 : Identify cities with highest and lowest total new passengers
WITH new_passengers AS(
SELECT 	 city_name, 
		 SUM(new_passengers) AS total_new_passengers,
         RANK() OVER (ORDER BY SUM(new_passengers) DESC) AS rnk
FROM 	 trips_db.fact_passenger_summary AS trip
JOIN 	 trips_db.dim_city AS city ON trip.city_id = city.city_id
GROUP BY city.city_id
)
SELECT 	 city_name, 
		 total_new_passengers,
		 (CASE WHEN (rnk=1 OR rnk=2 OR rnk=3) THEN "TOP 3"
			   WHEN (rnk=8 OR rnk=9 OR rnk=10) THEN "Bottom 3"
		  END) AS city_category 
FROM 	 new_passengers
WHERE NOT(rnk>3 AND rnk<8);


# Business Request 5 : Identify Month with Highest Renenue for Each city
WITH revenue_details AS(
SELECT 
		 city_id, 
         month_name,
         SUM(SUM(fare_amount)) OVER (PARTITION BY city_id) AS city_total_fare,
         SUM(fare_amount) AS city_month_total_fare,
         RANK() OVER (PARTITION BY city_id ORDER BY SUM(fare_amount) DESC) AS rnk
FROM 	 trips_db.fact_trips AS trip
JOIN 	 trips_db.dim_date AS d ON trip.date = d.date
GROUP BY city_id, month_name
ORDER BY city_id, rnk
)
SELECT 	 city_name,
		 month_name AS highest_revenue_month,
         city_month_total_fare AS revenue,
         CONCAT(ROUND((city_month_total_fare*100)/city_total_fare , 1) , '%') AS percentage_contribution
FROM 	 revenue_details
JOIN 	 trips_db.dim_city AS city ON revenue_details.city_id = city.city_id
#WHERE	 rnk=1
ORDER BY revenue DESC;
    
    
    
# Business Request 6 : Repeat Passenger Rate Analysis
# 1. Monthly Repeat Passenger rate 
# 2. City Wide Repeat Passenger Rate
WITH trip_summary AS(
SELECT 	distinct(month_name) AS months, 
		city_name, 
        total_passengers, 
        repeat_passengers,
        CONCAT(ROUND((repeat_passengers*100)/total_passengers,1) , '%') AS monthly_rpr,
        SUM(total_passengers) OVER (PARTITION BY city_name) AS city_total_passengers,
        SUM(repeat_passengers) OVER (PARTITION BY city_name) AS city_repeated_passengers,
        CONCAT(ROUND((SUM(repeat_passengers) OVER (PARTITION BY city_name))*100/SUM(total_passengers) OVER (PARTITION BY city_name),1) ,'%') AS city_rpr

FROM 	trips_db.fact_passenger_summary AS trip
JOIN 	trips_db.dim_city AS city ON trip.city_id = city.city_id
JOIN 	trips_db.dim_date AS d ON trip.month = d.start_of_month
)
SELECT 	 city_name,
		 months,
         total_passengers, 
         repeat_passengers,
		 #SUM(repeat_passengers) OVER (PARTITION BY city_name) AS city_repeated_passengers,
         #SUM(total_passengers) OVER (PARTITION BY city_name) AS city_total_passengers,
         CONCAT(ROUND((SUM(repeat_passengers) OVER (PARTITION BY city_name))*100/SUM(total_passengers) OVER (PARTITION BY city_name),1) ,'%') AS city_repeat_passenger_Rate
FROM 	 trip_summary
ORDER BY city_name, total_passengers, repeat_passengers
