# Case Study #3 - Foodie-Fi

## Project Overview
This case study analyses subscription data for Foodie-Fi, a fictional streaming platform focused on food content. The goal is to understand customer onboarding, plan transitions, churn behaviour and annual upgrade patterns using SQL.

## Business Problem
Foodie-Fi wants to make product and growth decisions using data. The questions focus on:
- how customers move through trial, paid plans and churn
- how many users upgrade to premium plans
- what the end-of-year subscription mix looks like
- how subscription payments should be modelled during 2020

## SQL Skills Used
- `JOIN`
- `CASE WHEN`
- `COUNT(DISTINCT ...)`
- `DATE_TRUNC`
- `ROW_NUMBER`, `LEAD`, `LAG`
- Common Table Expressions (CTEs)
- Recursive CTE approach for payment generation
- Bucketing with `WIDTH_BUCKET`

## Files
- `solution.sql` → main answers for sections A and B
- `payment_challenge.sql` → separate attempt for the 2020 payments challenge
- `scratch_work.sql` → intermediate exploration and ambiguity checks

## Business Value
This project demonstrates how SQL can be used to analyse a subscription business model:
- customer journey analysis
- churn measurement
- conversion tracking after free trial
- time-to-upgrade analysis
- event-based revenue logic preparation

## What I Practiced
- translating business questions into SQL
- working with sequential customer events
- handling date-based state snapshots
- separating main solution logic from exploration notes
- documenting assumptions when community answers conflict

## Notes
For Question 8, some community solutions count customers whose **next** plan becomes annual while their current row is still in 2020. In this portfolio version, I use the stricter interpretation: count customers whose **actual annual plan row starts in 2020**.

## Source
- Official case study: https://8weeksqlchallenge.com/case-study-3/
