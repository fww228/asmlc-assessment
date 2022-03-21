install.packages("infotheo")
install.packages("caret")
install.packages("tidyverse")
install.packages("ggplot2")
install.packages("GGally")
install.packages("data.table")
install.packages("mlr3verse")
install.packages("mlr3learners")
install.packages("mlr3proba")

library("tidyverse")
library("ggplot2")
library("GGally")
library("infotheo")
library("caret")
library("data.table")
library("mlr3verse")
library("mlr3learners")
library("mlr3proba")

hotels0 = readr::read_csv("https://www.louisaslett.com/Courses/MISCADA/hotels.csv")

# Figure 1
ggplot(hotels0 %>% filter(adr < 4000) %>% mutate(total_nights = stays_in_weekend_nights+stays_in_week_nights), 
       aes(x = adr, y = total_nights)) + geom_point(alpha=0.1)

# Figure 2-5
DataExplorer::plot_boxplot(hotels0, by = "is_canceled", ncol = 3)
DataExplorer::plot_bar(hotels0, by = "is_canceled", ncol = 2)

# Data cleaning
hotels1 <- hotels0 %>%
  mutate(total_nights = stays_in_weekend_nights+stays_in_week_nights) %>% 
  mutate(kids = case_when(children + babies > 0 ~ "kids", TRUE ~ "none")) %>%
  mutate(room_type = case_when(reserved_room_type == assigned_room_type ~ 1, TRUE ~ 0)) %>% 
  mutate(parking = case_when(required_car_parking_spaces > 0 ~ "parking", TRUE ~ "none")) %>% 
  mutate(arrival_date_month = as.integer(match(substr(arrival_date_month,1,3), month.abb)))

hotels2 <- hotels1 %>%
  select(-reservation_status, -reservation_status_date, -stays_in_weekend_nights, -stays_in_week_nights, 
         -children, -babies, -reserved_room_type, -assigned_room_type, -required_car_parking_spaces, 
         -country, -agent, -company, -arrival_date_year, -arrival_date_month, -arrival_date_day_of_month, 
         -arrival_date_week_number)

# Figure 6-7
ggpairs(hotels2 %>% select(hotel, meal, market_segment, distribution_channel, deposit_type, 
                           customer_type, kids, parking, adr, adults, is_canceled), aes(color = kids))
ggpairs(hotels2 %>% select(kids, lead_time, is_repeated_guest, previous_cancellations, 
                           previous_bookings_not_canceled, previous_bookings_not_canceled, 
                           booking_changes, days_in_waiting_list, total_of_special_requests, 
                           total_nights, room_type, is_canceled), aes(color = kids))

# Data cleaning
hotels3 <- hotels2 %>% 
  select(-hotel, -meal, -market_segment, -distribution_channel, -kids, -parking, -adr, -total_nights)
hotels4 <- hotels3 %>% select(-days_in_waiting_list)

# Figure 8
hotels4 %>% group_by(lead_time) %>% summarise(prop = mean(is_canceled)) %>% ggplot(aes(x=lead_time, y=prop))+
  geom_bar(stat='identity', width=2)

# Modeling
equal_freq_data <- discretize(hotels4$lead_time, 'equalfreq', 4)
sort_data <- hotels4$lead_time[order(hotels4$lead_time)]
hotels <- hotels4 %>%
  mutate(lead_time = case_when(lead_time>160 ~ 4, lead_time>69 & lead_time<=160 ~ 3, 
                               lead_time>18 & lead_time<=69 ~ 2, TRUE ~ 1))

# Simple logistic regression
fit.lr <- glm(as.factor(is_canceled) ~ ., binomial, hotels)

# Figure 9
pred.lr <- predict(fit.lr, hotels, type = "response")
ggplot(data.frame(x = pred.lr), aes(x = x)) + geom_histogram()

# Result of simple logistic regression
conf.mat <- table(`canceled` = hotels$is_canceled, `predict cancel` = pred.lr > 0.5)
conf.mat
conf.mat/rowSums(conf.mat)*100

# Model improvements
## Add hyperparameter epsilon
fit.lr <- glm(as.factor(is_canceled) ~ ., binomial, hotels, epsilon = 1e-5)
pred.lr <- predict(fit.lr, hotels, type = "response")
conf.mat <- table(`canceled` = hotels$is_canceled, `predict cancel` = pred.lr > 0.5)
# Figure 12 and 13
conf.mat
conf.mat/rowSums(conf.mat)*100

## Cross validation
hotels <- hotels %>% select(-customer_type, -adults)
hotels$deposit_type <- factor(hotels$deposit_type, levels=c("No Deposit", "Non Refund", "Refundable"), ordered = TRUE)
hotels$is_canceled <- factor(hotels$is_canceled, levels=c("0", "1"), ordered = TRUE)
hotels$lead_time <- factor(hotels$lead_time)
hotels$is_repeated_guest <- factor(hotels$is_repeated_guest)
hotels$previous_cancellations <- factor(hotels$previous_cancellations)
hotels$previous_bookings_not_canceled <- factor(hotels$previous_bookings_not_canceled)
hotels$booking_changes <- factor(hotels$booking_changes)
hotels$total_of_special_requests <- factor(hotels$total_of_special_requests)

set.seed(26)
hotels_task <- TaskClassif$new(id = "hotels", backend = na.omit(hotels), target = "is_canceled")
cv5 <- rsmp("cv", folds = 5)
cv5$instantiate(hotels_task)

lrn_cart_cv <- lrn("classif.rpart", predict_type = "prob", xval = 10)
res_cart_cv <- resample(hotels_task, lrn_cart_cv, cv5, store_models = TRUE)
# Figure 10
rpart::plotcp(res_cart_cv$learners[[5]]$model)

# Diﬀerent models and super learner
lrnsp_log_reg <- lrn("classif.log_reg", predict_type = "prob", id = "super")
pl_missing <- po("fixfactors") %>>%
  po("removeconstants") %>>%
  po("imputesample", affect_columns = selector_type(c("ordered", "factor"))) %>>%
  po("imputemean")
pl_factor <- po("encode")
spr_lrn <- gunion(list(
  gunion(list(
    po("learner_cv", lrn_baseline),
    po("learner_cv", lrn_cart),
    po("learner_cv", lrn_cart_cp)
  )),
  pl_missing %>>%
    gunion(list(
      po("learner_cv", lrn_ranger),
      po("learner_cv", lrn_log_reg),
      po("nop")
    )),
  pl_factor %>>%
    po("learner_cv", lrn_xgboost)
)) %>>%
  po("featureunion") %>>%
  po(lrnsp_log_reg)
# Figure 11
spr_lrn$plot()
res_spr <- resample(hotels_task, spr_lrn, cv5, store_models = TRUE)
res_spr$aggregate(list(msr("classif.ce"),
                       msr("classif.acc"),
                       msr("classif.fpr"),
                       msr("classif.fnr")))

