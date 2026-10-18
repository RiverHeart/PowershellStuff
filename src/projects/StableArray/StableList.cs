using System;
using System.Collections;
using System.Collections.Generic;

/// <summary>
/// A mutable list that PowerShell treats as a single object.
/// Use GetEnumerator() for explicit iteration or ToArray() for a shallow snapshot.
/// This type deliberately does not implement IEnumerable.
/// </summary>
public class StableList
{
    private readonly List<object> items = new List<object>();

    public bool FilterNulls { get; set; }

    public int Count
    {
        get { return items.Count; }
    }

    /// <summary>
    /// Gets or replaces an item using a zero-based index.
    /// Negative indices and indices greater than or equal to Count are invalid.
    /// FilterNulls applies only to Add, not to item replacement.
    /// </summary>
    public object this[int index]
    {
        get { return items[index]; }
        set { items[index] = value; }
    }

    public StableList()
    {
    }

    /// <summary>
    /// Creates an empty list for null, copies array elements, or stores a scalar
    /// as one item. Nested arrays and non-array collections remain single items.
    /// </summary>
    public StableList(object items)
    {
        if (items == null)
        {
            return;
        }

        Array array = items as Array;
        if (array != null)
        {
            foreach (object item in array)
            {
                this.items.Add(item);
            }
        }
        else
        {
            this.items.Add(items);
        }
    }

    public void Add(object item)
    {
        if (FilterNulls && item == null)
        {
            return;
        }

        items.Add(item);
    }

    public void Clear()
    {
        items.Clear();
    }

    public IEnumerator GetEnumerator()
    {
        return items.GetEnumerator();
    }

    public object[] ToArray()
    {
        return items.ToArray();
    }
}


/// <summary>
/// A mutable generic list that PowerShell treats as a single object.
/// Use GetEnumerator() for explicit iteration or ToArray() for a shallow snapshot.
/// This type deliberately does not implement IEnumerable.
/// </summary>
public class StableList<T>
{
    private readonly List<T> items = new List<T>();

    public bool FilterNulls { get; set; }

    public int Count
    {
        get { return items.Count; }
    }

    /// <summary>
    /// Gets or replaces an item using a zero-based index.
    /// Negative indices and indices greater than or equal to Count are invalid.
    /// FilterNulls applies to construction and Add, not to item replacement.
    /// </summary>
    public T this[int index]
    {
        get { return items[index]; }
        set { items[index] = value; }
    }

    public StableList()
    {
    }

    /// <summary>
    /// Copies the sequence's elements into the list, or creates an empty list for null.
    /// When filterNulls is true, null elements are skipped during construction and Add.
    /// </summary>
    public StableList(IEnumerable<T> items, bool filterNulls = false)
    {
        FilterNulls = filterNulls;
        if (null == items)
        {
            return;
        }

        foreach (T item in items)
        {
            Add(item);
        }
    }

    public void Add(T item)
    {
        if (FilterNulls && item == null)
        {
            return;
        }

        items.Add(item);
    }

    public void Clear()
    {
        items.Clear();
    }

    public IEnumerator<T> GetEnumerator()
    {
        return items.GetEnumerator();
    }

    public T[] ToArray()
    {
        return items.ToArray();
    }
}
