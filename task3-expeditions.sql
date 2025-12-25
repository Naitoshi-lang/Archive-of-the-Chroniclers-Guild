SELECT 
    name AS "Экспедиция",
    region AS "Регион",
    danger_level AS "Уровень опасности",
    CASE 
        WHEN danger_level = 5 THEN 'Крайне опасно'
        WHEN danger_level = 4 THEN 'Очень опасно'
        ELSE 'Опасно'
    END AS "Оценка риска"
FROM expeditions
WHERE danger_level >= 4
ORDER BY danger_level DESC, name;
