#!/bin/bash
# Скрипт для генерации manifest.json со списком файлов из папки Result

RESULT_DIR="Result"
MANIFEST_FILE="$RESULT_DIR/manifest.json"

if [ ! -d "$RESULT_DIR" ]; then
    echo "Ошибка: Папка $RESULT_DIR не найдена!" >&2
    exit 1
fi

# Создаем временный файл для списка файлов с датами
TEMP_FILE=$(mktemp)

# Находим все HTML файлы и получаем их даты модификации
cd "$RESULT_DIR" || exit 1
for file in *.html; do
    if [ -f "$file" ]; then
        # Получаем дату модификации файла
        if stat -f "%m" "$file" >/dev/null 2>&1; then
            # macOS
            timestamp=$(stat -f "%m" "$file")
        else
            # Linux
            timestamp=$(stat -c "%Y" "$file")
        fi
        
        # Извлекаем дату из имени файла
        if [[ $file =~ ([0-9]{4})-?([0-9]{2})-?([0-9]{2}) ]]; then
            year=${BASH_REMATCH[1]}
            month=${BASH_REMATCH[2]}
            day=${BASH_REMATCH[3]}
            date_from_name="${year}-${month}-${day}T00:00:00Z"
        else
            date_from_name=""
        fi
        
        # Форматируем дату модификации
        if command -v date >/dev/null 2>&1; then
            if date -d "@$timestamp" >/dev/null 2>&1; then
                # Linux
                date_iso=$(date -d "@$timestamp" -Iseconds 2>/dev/null)
            elif date -r "$timestamp" >/dev/null 2>&1; then
                # macOS
                date_iso=$(date -r "$timestamp" -Iseconds 2>/dev/null)
            else
                date_iso=""
            fi
        else
            date_iso=""
        fi
        
        echo "$timestamp|$file|$date_iso|$date_from_name" >> "$TEMP_FILE"
    fi
done

cd - >/dev/null || exit 1

# Сортируем по timestamp (новые первыми) и создаем JSON
echo "{" > "$MANIFEST_FILE"
echo "  \"files\": [" >> "$MANIFEST_FILE"

FIRST=true
while IFS='|' read -r timestamp filename date_iso date_from_name; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "$MANIFEST_FILE"
    fi
    
    commit_date=${date_from_name:-$date_iso}
    file_date=${date_iso:-$commit_date}
    
    echo -n "    {\"name\":\"$filename\",\"date\":\"$file_date\",\"commitDate\":\"$commit_date\"}" >> "$MANIFEST_FILE"
done < <(sort -t'|' -k1 -rn "$TEMP_FILE" 2>/dev/null || cat "$TEMP_FILE")

rm -f "$TEMP_FILE"

echo "" >> "$MANIFEST_FILE"
echo "  ]," >> "$MANIFEST_FILE"

# Генерируем текущую дату
if command -v date >/dev/null 2>&1; then
    generated_date=$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
else
    generated_date=""
fi

echo "  \"generated\": \"$generated_date\"" >> "$MANIFEST_FILE"
echo "}" >> "$MANIFEST_FILE"

# Исправляем если файлов нет
if [ "$FIRST" = true ]; then
    echo "{\"files\":[],\"generated\":\"$generated_date\"}" > "$MANIFEST_FILE"
fi

echo "✅ Успешно создан $MANIFEST_FILE"
if [ "$FIRST" = false ]; then
    echo "Найдено файлов: $(grep -c '"name"' "$MANIFEST_FILE" 2>/dev/null || echo 0)"
fi
