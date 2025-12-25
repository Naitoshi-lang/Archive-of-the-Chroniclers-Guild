SELECT 
    c.name AS "Хронист",
    c.rank AS "Ранг хрониста",
    e.name AS "Экспедиция",
    e.region AS "Регион экспедиции",
    ep.role AS "Роль в экспедиции",
    e.danger_level AS "Уровень опасности",
    ep.gold_reward AS "Награда (золото)"
FROM expedition_participation ep
JOIN chroniclers c ON ep.chronicler_id = c.id
JOIN expeditions e ON ep.expedition_id = e.id
ORDER BY e.danger_level DESC, c.name;
