Idea

# Missed Parameterised Join

**Origin issue**: В сложносоставном запросе не очевидно, что что-то можно улучшить (особенно за счёт параметризованного NestLoop), если это не листовая нода.

Сложность в том, что мы не знаем, что могло быть лучше, поскольку лучший вариант никогда не рассматривался оптимизатором (нет индекса) и не выполнялся.

А что, если на определенном по какому-то критерию запросе выполнить его планирование с предположением, что на каждую clause у нас есть соответствующий индекс?
Альтернативные index_adviser's имеются, но они предполагают какой-то конкретный индекс, а мы просто прпедложим все варианты и посмотрим, получится ли кардинально снизить кост.

Далее, зная этот кост можно высчитывать множитель для времени выполнения. Потом, имея кумуляттивную статистику по временам выполнения запросов, оценивать эффект на данных pg_stat_statements и предлагать изменение, если он существенен.

# А как конкретно такое сделать?

## Типовой путь

604ffd2, get_relation_info_hook
Не поможет: At this moment of call, we have no idea about the clauses

## Альтернатива

set_rel_pathlist_hook
set_join_pathlist_hook
set_rel_pathlist_hook may add 'hypothetical' indexes for each clause (clause combinations) from baserestrictinfo and joininfo, and re-launch the search (in fact, we only need to create_index_paths).

set_join_pathlist_hook may pass the joinclause through, add new indexes, and call add_paths_to_joinrel. We need only PNL, so , may be just limit
