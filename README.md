# asmlc-assessment

This is the repo of the assessment of class ASML:Classification.

## 字段名

id 字段名 解析
1 hotel 酒店类型：city hotel（城市酒店），resort hotel（度假酒店）
2 is_canceled 订单是否取消：1（取消），0（没有取消）
3 lead_time 下单日期到抵达酒店日期之间间隔的天数
4 arrival_date_year 抵达年份：2015、2016、2017
5 arrival_date_month 抵达月份：1月-12月
6 arrival_date_day_of_month 抵达日期：1-31日
7 arrival_date_week_number 抵达的年份周数：第1-72周
8 stays_in_weekend_nights 周末（星期六或星期天）客人入住或预定入住酒店的次数
9 stays_in_week_nights 每周晚上（星期一至星期五）客人入住或预定入住酒店的次数
10 adults 成年人数
11 children 儿童人数
12 babies 婴儿人数
13 meal 预订的餐型：SC\BB\HB\FB
14 country 国籍
15 market_segment 细分市场
16 distribution_channel 预订分销渠道
17 is_repeated_guest 订单是否来自老客户（以前预订过的客户）：1（是）0（否）
18 previous_cancellations 客户在当前预订前取消的先前预订数
19 previous_bookings_not_canceled 客户在本次预订前未取消的先前预订数
20 reserved_room_type 给客户保留的房间类型
21 assigned_room_type 客户下单时指定的房间类型
22 booking_changes 从预订在PMS系统中输入之日起至入住或取消之日止，对预订所作的更改/修改的数目
23 deposit_type 预付定金类型，是否可以退还：No Deposit（无订金）Non Refund（不可退）Refundable（可退）
24 agent 预订的旅行社
25 company 下单的公司（由它付钱）
26 days_in_waiting_list 订单被确认前，需要等待的天数
27 customer_type 客户类型
28 adr 平均每日收费，住宿期间的所有交易费用之和/住宿晚数
29 required_car_parking_spaces 客户要求的停车位数
30 total_of_special_requests 客户提出的特殊要求的数量(例如。 双人床或高层)
31 reservation_status 订单的最后状态：canceled（订单取消）Check-Out（客户已入住并退房）No-show（客户没有出现，并且告知酒店原因）
32 reservation_status_date 订单的最后状态的设置日期
ps：当is_canceled为1（取消）时，后面的数据并不是都为0，而是正常的数值，说明，这里的信息代表的是预订的时候的信息，比如lead_time，代表的是预订之日，到预计抵达之日之间间隔的日期，而非实际抵达的日期。


## Summary

1、该数据集一共有119390行，32个变量。
2、重复的行数有26.8%。
3、缺失率3.4%，含有缺失值的变量由：children、agent、country、company。
4、异常值：adr中包含负值、可能的显著离群点。
5、85%以上数据为0的变量：children、babies、is_repeated_guest、previous_cancellations、previous_bookings_not_canceled、booking_changes、day_in_waiting_list、required_car_parking_spaces。
6、订单的时间范围为：2015/7/1–2017/8/31，全面跨越的年度只有2016年。


## 缺失值

1、children 有4个缺失值，缺失率<0.01%，应该是没有children入住，用0填充
2、agent 有16340个缺失值，很可能是非机构客户预订的，为个人客户，用0填充
3、country 有488个缺失值，缺失率约0.409%，可能是采集的时候出的问题，用众数进行填充
4、company 中缺失值率超过94%，说明大多数订单是个人客户，之后可以分别对公司和个人预订的行为进行分析，暂用0填充


## 异常值

1、adult、children、babies同时为0的情况不合理，共180行，把这些类数据删除。
2、adr平均每日收费中，有1行为负值，删掉。
3、adr中最大值为5400，其他数据均在510以内，且相似的订单（总人数、房型、年月份、特殊要求数，用餐类型相同）的平均adr仅为69，由此判断此值为显著离群点，删除。
4、undefined值
market_segment中2个undefined，用众数Online TA替换。
distribution_channel有5个undefined，用众数TO/TA替换。
meal中有1169个undefined，应该是没有订任何餐型，跟SC意义相同，用SC替换。

ps：存在一些看似不太合理，但根据业务具体情况，有可能是合理的数据，不进行处理。比如：

1、对于previous_bookings_not_canceled，当is_repeated_guest为0（全新客户）的时候，此字段有783行数据不为0，即存在这样的客户：在预定日期到抵达日期这个时间段里，下了多个订单。所以，is_repeated_guest为0，previous_bookings_not_canceled不为0，是合理的。

2、stays_in_weekend_nights+stays_in_week_nights=0（总住宿晚数）的adr全部为零，而adr为0的时候，stays_in_weekend_nights+stays_in_week_nights不一定为0。第一，考虑adr是根据总住宿费用/总住宿晚数来计算的，所以出现第一种情况很正常，如果在实际场景中的分析，需要重新考量adr的计算方法，这里为了可以进行下一步的分析，暂时把这种情况定义为合理情况。而第二种情况，可能是由于平台给出的优惠，搞活动之类的，吸引客户，不用给钱也可以住宿。


## 数据转化与重组

为了方便分析，需要对一些数据类型进行修改，或者增加分析变量。
1、增加一列总住宿晚数stays_nights_total
=（stays_in_weekend_nights+stays_in_week_nights）。
2、增加一列住宿人数number_of_people
=(adults+children+babies) 或 kids=children+babies


## 分析

不同的酒店，面对的客户类型不同，营销策略也会有明显差异，也可能会有不同的趋势，在进行分析的时候，如果忽略不同酒店的影响，仅对总体进行分析，那么无论是趋势分析，或者用户结构分析，可能都会模糊掉一些信息，所以，对以下的分析，我都会先对总体进行分析，在对不同酒店类型进行分析。

