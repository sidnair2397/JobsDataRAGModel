select * from Job_Fact_Table;
select * from Job_Skill_Bridge_Table;
select * from Skill_Dimension_Table;
select * from Job_Key_Phrase_Table;
select * from Job_Entity_Table;
select * from Company_Dimension_Table;

select * from vw_JobWithSkills;
select * from vw_SkillDemand;
select * from vw_SalaryByRole
ORDER BY avg_salary_max DESC;
select * from vw_SalaryByLocation;