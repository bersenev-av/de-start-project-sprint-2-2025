/* создание таблицы tmp_sources с данными из всех источников */
drop table if exists tmp_sources;

create temp table tmp_sources as 
select
    order_id,
    order_created_date,
    order_completion_date,
    order_status,
    craftsman_id, --  skdnakldnalsndlksan
    craftsman_name,
    craftsman_address,
    craftsman_birthday,
    craftsman_email,
    product_id,
    product_name,
    product_description,
    product_type,
    product_price,
    customer_id,
    customer_name,
    customer_address,
    customer_birthday,
    customer_email
from
    source1.craft_market_wide
union
select
    t2.order_id,
    t2.order_created_date,
    t2.order_completion_date,
    t2.order_status,
    t1.craftsman_id,
    t1.craftsman_name,
    t1.craftsman_address,
    t1.craftsman_birthday,
    t1.craftsman_email,
    t1.product_id,
    t1.product_name,
    t1.product_description,
    t1.product_type,
    t1.product_price,
    t2.customer_id,
    t2.customer_name,
    t2.customer_address,
    t2.customer_birthday,
    t2.customer_email
from
    source2.craft_market_masters_products t1
join source2.craft_market_orders_customers t2 on
    t2.product_id = t1.product_id
    and t1.craftsman_id = t2.craftsman_id
union
select
    t1.order_id,
    t1.order_created_date,
    t1.order_completion_date,
    t1.order_status,
    t2.craftsman_id,
    t2.craftsman_name,
    t2.craftsman_address,
    t2.craftsman_birthday,
    t2.craftsman_email,
    t1.product_id,
    t1.product_name,
    t1.product_description,
    t1.product_type,
    t1.product_price,
    t3.customer_id,
    t3.customer_name,
    t3.customer_address,
    t3.customer_birthday,
    t3.customer_email
from
    source3.craft_market_orders t1
join source3.craft_market_craftsmans t2 on
    t1.craftsman_id = t2.craftsman_id
join source3.craft_market_customers t3 on
    t1.customer_id = t3.customer_id
union
select
    order_id,
    order_created_date,
    order_completion_date,
    order_status,
    craftsman_id,
    craftsman_name,
    craftsman_address,
    craftsman_birthday,
    craftsman_email,
    product_id,
    product_name,
    product_description,
    product_type,
    product_price,
    c.customer_id,
    customer_name,
    customer_address,
    customer_birthday,
    customer_email
from
    external_source.craft_products_orders cpo
left join external_source.customers c on
    cpo.customer_id = c.customer_id;

/* обновление существующих записей и добавление новых в dwh.d_craftsmans */
merge
into
    dwh.d_craftsman d
        using (
    select
        distinct craftsman_name,
        craftsman_address,
        craftsman_birthday,
        craftsman_email
    from
        tmp_sources) t
on
    d.craftsman_name = t.craftsman_name
    and d.craftsman_email = t.craftsman_email
    when matched then
  update
set
    craftsman_address = t.craftsman_address,
    craftsman_birthday = t.craftsman_birthday,
    load_dttm = current_timestamp
    when not matched then
  insert
    (craftsman_name,
    craftsman_address,
    craftsman_birthday,
    craftsman_email,
    load_dttm)
values (t.craftsman_name,
t.craftsman_address,
t.craftsman_birthday,
t.craftsman_email,
current_timestamp);

/* обновление существующих записей и добавление новых в dwh.d_products */
merge
into
    dwh.d_product d
        using (
    select
        distinct product_name,
        product_description,
        product_type,
        product_price
    from
        tmp_sources) t
on
    d.product_name = t.product_name
    and d.product_description = t.product_description
    and d.product_price = t.product_price
    when matched then
  update
set
    product_type = t.product_type,
    load_dttm = current_timestamp
    when not matched then
  insert
    (product_name,
    product_description,
    product_type,
    product_price,
    load_dttm)
values (t.product_name,
t.product_description,
t.product_type,
t.product_price,
current_timestamp);

/* обновление существующих записей и добавление новых в dwh.d_customer */
merge
into
    dwh.d_customer d
        using (
    select
        distinct customer_name,
        customer_address,
        customer_birthday,
        customer_email
    from
        tmp_sources) t
on
    d.customer_name = t.customer_name
    and d.customer_email = t.customer_email
    when matched then
  update
set
    customer_address = t.customer_address,
    customer_birthday = t.customer_birthday,
    load_dttm = current_timestamp
    when not matched then
  insert
    (customer_name,
    customer_address,
    customer_birthday,
    customer_email,
    load_dttm)
values (t.customer_name,
t.customer_address,
t.customer_birthday,
t.customer_email,
current_timestamp);

/* создание таблицы tmp_sources_fact */
drop table if exists tmp_sources_fact;

create temp table tmp_sources_fact as 
select
    dp.product_id,
    dc.craftsman_id,
    dcust.customer_id,
    src.order_created_date,
    src.order_completion_date,
    src.order_status,
    current_timestamp
from
    tmp_sources src
join dwh.d_craftsman dc on
    dc.craftsman_name = src.craftsman_name
    and dc.craftsman_email = src.craftsman_email
join dwh.d_customer dcust on
    dcust.customer_name = src.customer_name
    and dcust.customer_email = src.customer_email
join dwh.d_product dp on
    dp.product_name = src.product_name
    and dp.product_description = src.product_description
    and dp.product_price = src.product_price;

/* обновление существующих записей и добавление новых в dwh.f_order */
merge
into
    dwh.f_order f
        using tmp_sources_fact t
on
    f.product_id = t.product_id
    and f.craftsman_id = t.craftsman_id
    and f.customer_id = t.customer_id
    and f.order_created_date = t.order_created_date
    when matched then
  update
set
    order_completion_date = t.order_completion_date,
    order_status = t.order_status,
    load_dttm = current_timestamp
    when not matched then
  insert
    (product_id,
    craftsman_id,
    customer_id,
    order_created_date,
    order_completion_date,
    order_status,
    load_dttm)
values (t.product_id,
t.craftsman_id,
t.customer_id,
t.order_created_date,
t.order_completion_date,
t.order_status,
current_timestamp);
-- DDL витрины данных
drop table if exists dwh.customer_report_datamart;

create table if not exists dwh.customer_report_datamart (
    id BIGINT generated always as identity not null,
-- идентификатор записи;
customer_id BIGINT not null,
-- идентификатор заказчика;
customer_name VARCHAR not null,
-- Ф. И. О. заказчика;
customer_address VARCHAR not null,
-- адрес заказчика;
customer_birthday DATE not null,
-- дата рождения заказчика;
customer_email VARCHAR not null,
-- электронная почта заказчика;
customer_money numeric(15, 2) not null,
-- сумма, которую потратил заказчик;
platform_money BIGINT not null,
-- сумма, которую заработала платформа от покупок заказчика за месяц (10% от суммы, которую потратил заказчик);
count_order BIGINT not null,
-- количество заказов у заказчика за месяц;
avg_price_order numeric(10, 2) not null,
-- средняя стоимость одного заказа у заказчика за месяц;
median_time_order_completed numeric(10, 1),
-- медианное время в днях от момента создания заказа до его завершения за месяц;
top_product_category VARCHAR not null,
-- самая популярная категория товаров у этого заказчика за месяц;
top_craftsman VARCHAR not null,
-- идентификатор самого популярного мастера ручной работы у заказчика.
count_order_created BIGINT not null,
-- количество созданных заказов за месяц;
count_order_in_progress BIGINT not null,
-- количество заказов в процессе изготовки за месяц;
count_order_delivery BIGINT not null,
-- количество заказов в доставке за месяц;
count_order_done BIGINT not null,
-- количество завершённых заказов за месяц;
count_order_not_done BIGINT not null,
-- количество незавершённых заказов за месяц;
report_period VARCHAR not null,
-- отчётный период, год и месяц.
    constraint customer_report_datamart_pk primary key (id)
);
-- DDL таблицы инкрементальных загрузок
drop table if exists dwh.load_dates_customer_report_datamart;

create table if not exists dwh.load_dates_customer_report_datamart (
    id BIGINT generated always as identity not null,
    load_dttm DATE not null,
    constraint load_dates_customer_report_datamart_pk primary key (id)
);

with dwh_delta as (
select
    dcs.customer_id as customer_id,
    dc.craftsman_id,
    dc.craftsman_name,
    dcs.customer_name as customer_name,
    dcs.customer_address as customer_address,
    dcs.customer_birthday as customer_birthday,
    dcs.customer_email as customer_email,
    fo.order_id as order_id,
    dp.product_id as product_id,
    dp.product_price as product_price,
    dp.product_type as product_type,
    fo.order_completion_date - fo.order_created_date as diff_order_date,
    fo.order_status as order_status,
    TO_CHAR(fo.order_created_date, 'yyyy-mm') as report_period,
    crd.customer_id as exist_customer_id,
    dc.load_dttm as craftsman_load_dttm,
    dcs.load_dttm as customers_load_dttm,
    dp.load_dttm as products_load_dttm
from
    dwh.f_order fo
inner join dwh.d_craftsman dc on
    fo.craftsman_id = dc.craftsman_id
inner join dwh.d_customer dcs on
    fo.customer_id = dcs.customer_id
inner join dwh.d_product dp on
    fo.product_id = dp.product_id
left join dwh.customer_report_datamart crd on
    dcs.customer_id = crd.customer_id
where
    (fo.load_dttm > (
    select
        coalesce(MAX(load_dttm), '1900-01-01')
    from
        dwh.load_dates_customer_report_datamart))
    or
                            (dc.load_dttm > (
    select
        coalesce(MAX(load_dttm), '1900-01-01')
    from
        dwh.load_dates_customer_report_datamart))
    or
                            (dcs.load_dttm > (
    select
        coalesce(MAX(load_dttm), '1900-01-01')
    from
        dwh.load_dates_customer_report_datamart))
    or
                            (dp.load_dttm > (
    select
        coalesce(MAX(load_dttm), '1900-01-01')
    from
        dwh.load_dates_customer_report_datamart))
                    ),
dwh_update_delta as (
select
    dd.exist_customer_id as customer_id
from
    dwh_delta dd
where
    dd.exist_customer_id is not null),
dwh_delta_insert_result as (
-- делаем расчёт витрины по новым данным.
select
    T4.customer_id as customer_id,
    T4.customer_name as customer_name,
    T4.customer_address as customer_address,
    T4.customer_birthday as customer_birthday,
    T4.customer_email as customer_email,
    T4.customer_money as customer_money,
    T4.platform_money as platform_money,
    T4.count_order as count_order,
    T4.avg_price_order as avg_price_order,
    T4.product_type as top_product_category,
    T4.craftsman_name as top_craftsman,
    T4.median_time_order_completed as median_time_order_completed,
    T4.count_order_created as count_order_created,
    T4.count_order_in_progress as count_order_in_progress,
    T4.count_order_delivery as count_order_delivery,
    T4.count_order_done as count_order_done,
    T4.count_order_not_done as count_order_not_done,
    T4.report_period as report_period
from
    (
    select
        -- в этой выборке объединяем две внутренние выборки по расчёту столбцов витрины и применяем оконную функцию для определения самой популярной категории товаров
                        *,
        rank() over(partition by T2.customer_id order by count_product desc) as rank_count_product,
        row_number() over (partition by T2.customer_id
    order by
        count_craftsman desc) as rank_count_crafsman
    from
        (
        select
            T1.customer_id as customer_id,
            T1.customer_name as customer_name,
            T1.customer_address as customer_address,
            T1.customer_birthday as customer_birthday,
            T1.customer_email as customer_email,
            SUM(T1.product_price) - (SUM(T1.product_price) * 0.1) as customer_money,
            SUM(T1.product_price) * 0.1 as platform_money,
            COUNT(order_id) as count_order,
            AVG(T1.product_price) as avg_price_order,
            PERCENTILE_CONT(0.5) within group(order by diff_order_date) as median_time_order_completed,
            SUM(case when T1.order_status = 'created' then 1 else 0 end) as count_order_created,
            SUM(case when T1.order_status = 'in progress' then 1 else 0 end) as count_order_in_progress,
            SUM(case when T1.order_status = 'delivery' then 1 else 0 end) as count_order_delivery,
            SUM(case when T1.order_status = 'done' then 1 else 0 end) as count_order_done,
            SUM(case when T1.order_status != 'done' then 1 else 0 end) as count_order_not_done,
            T1.report_period as report_period
        from
            dwh_delta as T1
        where
            T1.exist_customer_id is null
        group by
            T1.customer_id,
            T1.customer_name,
            T1.customer_address,
            T1.customer_birthday,
            T1.customer_email,
            T1.report_period
                            ) as T2
    inner join (
        select
            dd.customer_id as customer_id_for_product_type,
            dd.product_type,
            COUNT(dd.product_id) as count_product
        from
            dwh_delta as dd
        group by
            dd.customer_id,
            dd.product_type
        order by
            count_product desc) as T3 on
        T2.customer_id = T3.customer_id_for_product_type
    inner join (
        select
            dd.customer_id as customer_id_for_craftsman,
            dd.craftsman_name,
            COUNT(dd.craftsman_id) as count_craftsman
        from
            dwh_delta as dd
        group by
            dd.customer_id,
            dd.craftsman_name
        order by
            count_craftsman desc) as T5 on
        T2.customer_id = T5.customer_id_for_craftsman
                ) as T4
where
    T4.rank_count_product = 1
order by
    report_period
    -- условие помогает оставить в выборке первую по популярности категорию товаров
),
dwh_delta_update_result as (
-- делаем перерасчёт для существующих записей витринs, так как данные обновились за отчётные периоды. Логика похожа на insert, но нужно достать конкретные данные из DWH
select
    T4.customer_id as customer_id,
    T4.customer_name as customer_name,
    T4.customer_address as customer_address,
    T4.customer_birthday as customer_birthday,
    T4.customer_email as customer_email,
    T4.customer_money as customer_money,
    T4.platform_money as platform_money,
    T4.count_order as count_order,
    T4.avg_price_order as avg_price_order,
    T4.product_type as top_product_category,
    T4.craftsman_name as top_craftsman,
    T4.median_time_order_completed as median_time_order_completed,
    T4.count_order_created as count_order_created,
    T4.count_order_in_progress as count_order_in_progress,
    T4.count_order_delivery as count_order_delivery,
    T4.count_order_done as count_order_done,
    T4.count_order_not_done as count_order_not_done,
    T4.report_period as report_period
from
    (
    select
        -- в этой выборке объединяем две внутренние выборки по расчёту столбцов витрины и применяем оконную функцию для определения самой популярной категории товаров
                        *,
        rank() over(partition by T2.customer_id order by count_product desc) as rank_count_product,
        row_number() over (partition by T2.customer_id
    order by
        count_craftsman desc) as rank_count_crafsman
    from
        (
        select
            T1.customer_id as customer_id,
            T1.customer_name as customer_name,
            T1.customer_address as customer_address,
            T1.customer_birthday as customer_birthday,
            T1.customer_email as customer_email,
            SUM(T1.product_price) - (SUM(T1.product_price) * 0.1) as customer_money,
            SUM(T1.product_price) * 0.1 as platform_money,
            COUNT(order_id) as count_order,
            AVG(T1.product_price) as avg_price_order,
            PERCENTILE_CONT(0.5) within group(order by diff_order_date) as median_time_order_completed,
            SUM(case when T1.order_status = 'created' then 1 else 0 end) as count_order_created,
            SUM(case when T1.order_status = 'in progress' then 1 else 0 end) as count_order_in_progress,
            SUM(case when T1.order_status = 'delivery' then 1 else 0 end) as count_order_delivery,
            SUM(case when T1.order_status = 'done' then 1 else 0 end) as count_order_done,
            SUM(case when T1.order_status != 'done' then 1 else 0 end) as count_order_not_done,
            T1.report_period as report_period
        from
            (
            select
                -- в этой выборке достаём из DWH обновлённые или новые данные по клиентам, которые уже есть в витрине
                dcs.customer_id as customer_id,
                dcs.customer_name as customer_name,
                dcs.customer_address as customer_address,
                dcs.customer_birthday as customer_birthday,
                dcs.customer_email as customer_email,
                fo.order_id as order_id,
                dp.product_id as product_id,
                dp.product_price as product_price,
                dp.product_type as product_type,
                fo.order_completion_date - fo.order_created_date as diff_order_date,
                fo.order_status as order_status,
                TO_CHAR(fo.order_created_date, 'yyyy-mm') as report_period
            from
                dwh.f_order fo
            inner join dwh.d_craftsman dc on
                fo.craftsman_id = dc.craftsman_id
            inner join dwh.d_customer dcs on
                fo.customer_id = dcs.customer_id
            inner join dwh.d_product dp on
                fo.product_id = dp.product_id
            inner join dwh_update_delta ud on
                fo.customer_id = ud.customer_id
                                ) as T1
        group by
            T1.customer_id,
            T1.customer_name,
            T1.customer_address,
            T1.customer_birthday,
            T1.customer_email,
            T1.report_period
                            ) as T2
    inner join (
        select
            dd.customer_id as customer_id_for_product_type,
            dd.product_type,
            COUNT(dd.product_id) as count_product
        from
            dwh_delta as dd
        group by
            dd.customer_id,
            dd.product_type
        order by
            count_product desc) as T3 on
        T2.customer_id = T3.customer_id_for_product_type
    inner join (
        select
            dd.customer_id as customer_id_for_craftsman,
            dd.craftsman_name,
            COUNT(dd.craftsman_id) as count_craftsman
        from
            dwh_delta as dd
        group by
            dd.customer_id,
            dd.craftsman_name
        order by
            count_craftsman desc) as T5 on
        T2.customer_id = T5.customer_id_for_craftsman
                ) as T4
where
    T4.rank_count_product = 1
order by
    report_period
    -- условие помогает оставить в выборке первую по популярности категорию товаров
),
insert_delta as (
-- выполняем insert новых расчитанных данных для витрины 
insert
    into
        dwh.customer_report_datamart (
        customer_id,
        customer_name,
        customer_address,
        customer_birthday,
        customer_email,
        customer_money,
        platform_money,
        count_order,
        avg_price_order,
        median_time_order_completed,
        top_product_category,
        top_craftsman,
        count_order_created,
        count_order_in_progress,
        count_order_delivery,
        count_order_done,
        count_order_not_done,
        report_period
    )
        select
            customer_id,
            customer_name,
            customer_address,
            customer_birthday,
            customer_email,
            customer_money,
            platform_money,
            count_order,
            avg_price_order,
            median_time_order_completed,
            top_product_category,
            top_craftsman,
            count_order_created,
            count_order_in_progress,
            count_order_delivery,
            count_order_done,
            count_order_not_done,
            report_period
        from
            dwh_delta_insert_result
),
update_delta as (
update
    dwh.customer_report_datamart
set
    customer_name = updates.customer_name,
    customer_address = updates.customer_address,
    customer_birthday = updates.customer_birthday,
    customer_email = updates.customer_email,
    customer_money = updates.customer_money,
    platform_money = updates.platform_money,
    count_order = updates.count_order,
    avg_price_order = updates.avg_price_order,
    median_time_order_completed = updates.median_time_order_completed,
    top_product_category = updates.top_product_category,
    top_craftsman = updates.top_craftsman,
    count_order_created = updates.count_order_created,
    count_order_in_progress = updates.count_order_in_progress,
    count_order_delivery = updates.count_order_delivery,
    count_order_done = updates.count_order_done,
    count_order_not_done = updates.count_order_not_done,
    report_period = updates.report_period
from
    (
    select
        customer_id,
        customer_name,
        customer_address,
        customer_birthday,
        customer_email,
        customer_money,
        platform_money,
        count_order,
        avg_price_order,
        median_time_order_completed,
        top_product_category,
        top_craftsman,
        count_order_created,
        count_order_in_progress,
        count_order_delivery,
        count_order_done,
        count_order_not_done,
        report_period
    from
        dwh_delta_update_result) as updates
where
    dwh.customer_report_datamart.customer_id = updates.customer_id
),
insert_load_date as (
-- делаем запись в таблицу загрузок о том, когда была совершена загрузка, чтобы в следующий раз взять данные, которые будут добавлены или изменены после этой даты
insert
    into
        dwh.load_dates_customer_report_datamart (load_dttm)
        select
            greatest(coalesce(MAX(craftsman_load_dttm), NOW()), 
                    coalesce(MAX(customers_load_dttm), NOW()), 
                    coalesce(MAX(products_load_dttm), NOW()))
        from
            dwh_delta
)
select
    'increment datamart';
-- инициализируем запрос CTE 